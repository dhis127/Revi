import Flutter
import Vision
import UIKit
import ImageIO

public class OcrPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "revi/ocr",
      binaryMessenger: registrar.messenger()
    )
    let instance = OcrPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // UIImage.Orientation → CGImagePropertyOrientation 변환
  // Vision은 CGImagePropertyOrientation을 요구하지만 UIImage는 별도 열거형을 사용함
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

  func recognizeTextFromImage(at imagePath: String, _ result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let image = UIImage(contentsOfFile: imagePath),
            let cgImage = image.cgImage else {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
        }
        return
      }

      // EXIF orientation을 Vision에 전달 — 미전달 시 raw 픽셀 기준으로 인식해
      // 박스가 90° 어긋나고 인식 정확도가 0에 가까워짐
      let orientation = self.cgOrientation(from: image.imageOrientation)
      let requestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                 orientation: orientation,
                                                 options: [:])

      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate
      textRequest.usesLanguageCorrection = true
      textRequest.recognitionLanguages = ["ko-KR", "en-US"]
      textRequest.minimumTextHeight = 0.008  // 작은 글씨도 인식

      // iOS 16+: 언어 자동 감지 활성화
      if #available(iOS 16.0, *) {
        textRequest.automaticallyDetectsLanguage = true
      }

      do {
        try requestHandler.perform([textRequest])

        guard let observations = textRequest.results as? [VNRecognizedTextObservation] else {
          DispatchQueue.main.async { result([]) }
          return
        }

        var results: [[String: Any]] = []
        for observation in observations {
          guard let candidate = observation.topCandidates(1).first else { continue }
          let fullText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
          guard fullText.count > 1 else { continue }
          let conf = Double(candidate.confidence)

          // 단어 단위 bounding box 추출
          let wordItems = self.wordBoundingBoxes(candidate: candidate, text: fullText, confidence: conf)
          if !wordItems.isEmpty {
            results.append(contentsOf: wordItems)
          } else {
            // 단어 추출 실패 시 줄 단위로 폴백
            let box = observation.boundingBox
            results.append([
              "text": fullText,
              "x": Double(box.minX),
              "y": Double(box.minY),
              "w": Double(box.width),
              "h": Double(box.height),
              "confidence": conf,
            ])
          }
        }

        DispatchQueue.main.async { result(results) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "OCR_ERROR", message: "Text recognition failed", details: error.localizedDescription))
        }
      }
    }
  }

  // ── 단어 단위 bounding box ────────────────────────────────────────────────
  private func wordBoundingBoxes(candidate: VNRecognizedText,
                                 text: String,
                                 confidence: Double) -> [[String: Any]] {
    var items: [[String: Any]] = []
    var searchPos = text.startIndex

    for component in text.components(separatedBy: " ") {
      guard !component.isEmpty, searchPos < text.endIndex else { continue }
      let remaining = searchPos..<text.endIndex
      guard let wordRange = text.range(of: component, options: [], range: remaining),
            let rectObs = try? candidate.boundingBox(for: wordRange) else {
        // 범위 찾기 실패 시 스킵 (searchPos는 유지)
        continue
      }
      let box = rectObs.boundingBox
      items.append([
        "text": component,
        "x": Double(box.minX),
        "y": Double(box.minY),
        "w": Double(box.width),
        "h": Double(box.height),
        "confidence": confidence,
      ])
      searchPos = wordRange.upperBound
      if searchPos < text.endIndex {
        searchPos = text.index(after: searchPos) // 공백 건너뜀
      }
    }
    return items
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "recognizeText" {
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      recognizeTextFromImage(at: imagePath, result)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
