import Flutter
import Vision
import UIKit
import ImageIO
import CoreImage
import CoreImage.CIFilterBuiltins

private struct OcrLineResult {
  let text: String
  let box: CGRect
  let confidence: Double
}

public class OcrPlugin: NSObject, FlutterPlugin {
  private let ciContext = CIContext(options: nil)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "revi/ocr",
      binaryMessenger: registrar.messenger()
    )
    let instance = OcrPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch uiOrientation {
    case .up:            return .up
    case .down:          return .down
    case .left:          return .left
    case .right:         return .right
    case .upMirrored:    return .upMirrored
    case .downMirrored:  return .downMirrored
    case .leftMirrored:  return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default:    return .up
    }
  }

  private func normalizedImage(from image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    let format = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    format.opaque = true
    return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }

  private func enhancedCGImage(
    from cgImage: CGImage,
    contrast: Float,
    brightness: Float,
    saturation: Float,
    sharpness: Float
  ) -> CGImage? {
    let input = CIImage(cgImage: cgImage)

    let controls = CIFilter.colorControls()
    controls.inputImage = input
    controls.contrast = contrast
    controls.brightness = brightness
    controls.saturation = saturation

    guard var output = controls.outputImage else { return nil }

    if sharpness > 0 {
      let sharpen = CIFilter.sharpenLuminance()
      sharpen.inputImage = output
      sharpen.sharpness = sharpness
      if let sharpened = sharpen.outputImage {
        output = sharpened
      }
    }

    return ciContext.createCGImage(output, from: output.extent)
  }

  private func imageVariants(from image: UIImage, enhanced: Bool) -> [(CGImage, CGImagePropertyOrientation)] {
    guard let original = image.cgImage else { return [] }
    if !enhanced {
      return [(original, cgOrientation(from: image.imageOrientation))]
    }

    let normalized = normalizedImage(from: image)
    guard let base = normalized.cgImage else {
      return [(original, cgOrientation(from: image.imageOrientation))]
    }

    var variants: [(CGImage, CGImagePropertyOrientation)] = [(base, .up)]
    if let contrast = enhancedCGImage(
      from: base,
      contrast: 1.28,
      brightness: 0.02,
      saturation: 0.0,
      sharpness: 0.35
    ) {
      variants.append((contrast, .up))
    }
    if let hardContrast = enhancedCGImage(
      from: base,
      contrast: 1.55,
      brightness: 0.04,
      saturation: 0.0,
      sharpness: 0.65
    ) {
      variants.append((hardContrast, .up))
    }
    if let dimText = enhancedCGImage(
      from: base,
      contrast: 1.42,
      brightness: -0.02,
      saturation: 0.0,
      sharpness: 0.5
    ) {
      variants.append((dimText, .up))
    }
    return variants
  }

  private func configuredTextRequest(enhanced: Bool) -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.minimumTextHeight = enhanced ? 0.0 : 0.003

    if #available(iOS 16.0, *) {
      request.automaticallyDetectsLanguage = true
    }

    return request
  }

  private func runVision(
    cgImage: CGImage,
    orientation: CGImagePropertyOrientation,
    enhanced: Bool
  ) throws -> [OcrLineResult] {
    let requestHandler = VNImageRequestHandler(
      cgImage: cgImage,
      orientation: orientation,
      options: [:]
    )
    let textRequest = configuredTextRequest(enhanced: enhanced)
    try requestHandler.perform([textRequest])

    guard let observations = textRequest.results as? [VNRecognizedTextObservation] else {
      return []
    }

    var lines: [OcrLineResult] = []
    for observation in observations {
      for candidate in observation.topCandidates(enhanced ? 3 : 1) {
        let fullText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullText.isEmpty else { continue }
        lines.append(OcrLineResult(
          text: fullText,
          box: observation.boundingBox,
          confidence: Double(candidate.confidence)
        ))
      }
    }

    return lines.sorted { lhs, rhs in
      if abs(lhs.box.minY - rhs.box.minY) > 0.012 {
        return lhs.box.minY > rhs.box.minY
      }
      return lhs.box.minX < rhs.box.minX
    }
  }

  private func score(lines: [OcrLineResult]) -> Double {
    if lines.isEmpty { return -Double.greatestFiniteMagnitude }
    let text = lines.map { $0.text }.joined(separator: " ")
    let scalarCount = text.unicodeScalars.count
    let avgConfidence = lines.map { $0.confidence }.reduce(0, +) / Double(lines.count)
    let replacementPenalty = Double(text.filter { $0 == "�" || $0 == "?" }.count) * 0.35
    let tinyLinePenalty = lines.filter { $0.box.height < 0.015 }.count == lines.count ? 0.5 : 0.0
    return avgConfidence * 2.0 + min(Double(scalarCount), 160.0) / 160.0 - replacementPenalty - tinyLinePenalty
  }

  private func candidateScore(_ line: OcrLineResult, supportCount: Int) -> Double {
    let scalarCount = line.text.unicodeScalars.count
    let replacementPenalty = Double(line.text.filter { $0 == "�" || $0 == "?" }.count) * 0.45
    let oddPunctuationPenalty = Double(line.text.filter { "{}[]|_~".contains($0) }.count) * 0.15
    let lengthBonus = min(Double(scalarCount), 80.0) / 80.0
    let supportBonus = min(Double(supportCount), 4.0) * 0.12
    return line.confidence * 2.0 + lengthBonus + supportBonus - replacementPenalty - oddPunctuationPenalty
  }

  private func boxesLikelySameLine(_ a: CGRect, _ b: CGRect) -> Bool {
    let yOverlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
    let minHeight = max(min(a.height, b.height), 0.0001)
    if yOverlap / minHeight >= 0.45 { return true }

    let centerDistance = abs(a.midY - b.midY)
    let tolerance = max(max(a.height, b.height) * 0.55, 0.018)
    return centerDistance <= tolerance
  }

  private func mergeLineCandidates(from runs: [[OcrLineResult]]) -> [OcrLineResult] {
    var groups: [[OcrLineResult]] = []

    for line in runs.flatMap({ $0 }) {
      if let index = groups.firstIndex(where: { group in
        guard let first = group.first else { return false }
        return boxesLikelySameLine(first.box, line.box)
      }) {
        groups[index].append(line)
      } else {
        groups.append([line])
      }
    }

    let merged = groups.compactMap { group -> OcrLineResult? in
      let textFrequency = group.reduce(into: [String: Int]()) { counts, line in
        counts[line.text, default: 0] += 1
      }
      let best = group.max { lhs, rhs in
        candidateScore(lhs, supportCount: textFrequency[lhs.text] ?? 1)
          < candidateScore(rhs, supportCount: textFrequency[rhs.text] ?? 1)
      }
      return best
    }

    return merged.sorted { lhs, rhs in
      if abs(lhs.box.minY - rhs.box.minY) > 0.012 {
        return lhs.box.minY > rhs.box.minY
      }
      return lhs.box.minX < rhs.box.minX
    }
  }

  func recognizeTextFromImage(
    at imagePath: String,
    enhanced: Bool,
    _ result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let image = UIImage(contentsOfFile: imagePath) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
        }
        return
      }

      do {
        var variantRuns: [[OcrLineResult]] = []
        var bestLines: [OcrLineResult] = []
        var bestScore = -Double.greatestFiniteMagnitude

        for (cgImage, orientation) in self.imageVariants(from: image, enhanced: enhanced) {
          let lines = try self.runVision(
            cgImage: cgImage,
            orientation: orientation,
            enhanced: enhanced
          )
          variantRuns.append(lines)
          let currentScore = self.score(lines: lines)
          if currentScore > bestScore {
            bestScore = currentScore
            bestLines = lines
          }
        }

        let finalLines = enhanced
          ? self.mergeLineCandidates(from: variantRuns)
          : bestLines

        let results: [[String: Any]] = finalLines.map { line in
          [
            "text": line.text,
            "x": Double(line.box.minX),
            "y": Double(line.box.minY),
            "w": Double(line.box.width),
            "h": Double(line.box.height),
            "confidence": line.confidence,
          ]
        }

        DispatchQueue.main.async { result(results) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "OCR_ERROR",
                              message: "Text recognition failed",
                              details: error.localizedDescription))
        }
      }
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "recognizeText" {
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      let enhanced = args["enhanced"] as? Bool ?? false
      recognizeTextFromImage(at: imagePath, enhanced: enhanced, result)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
