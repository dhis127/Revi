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

      let orientation = self.cgOrientation(from: image.imageOrientation)
      let requestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                 orientation: orientation,
                                                 options: [:])

      let textRequest = VNRecognizeTextRequest()
      textRequest.recognitionLevel = .accurate
      textRequest.usesLanguageCorrection = true
      textRequest.recognitionLanguages = ["ko-KR", "en-US"]
      // 0.003: 각주·소형 텍스트까지 인식 (기존 0.008은 각주를 놓침)
      textRequest.minimumTextHeight = 0.003

      if #available(iOS 16.0, *) {
        textRequest.automaticallyDetectsLanguage = true
      }

      do {
        try requestHandler.perform([textRequest])

        guard let observations = textRequest.results as? [VNRecognizedTextObservation] else {
          DispatchQueue.main.async { result([]) }
          return
        }

        // ── 줄(line) 단위로 반환 ──────────────────────────────────────────────
        // Vision은 observations를 읽기 순서(위→아래, 왼→오른)로 반환하므로
        // 줄 단위를 그대로 사용하면 단어 단위보다 순서가 훨씬 정확함.
        // 책 페이지가 휘어진 경우에도 줄 내부 텍스트는 Vision이 이미 올바르게 정렬함.
        var results: [[String: Any]] = []
        for observation in observations {
          guard let candidate = observation.topCandidates(1).first else { continue }
          let fullText = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !fullText.isEmpty else { continue }
          let conf = Double(candidate.confidence)
          let box  = observation.boundingBox

          results.append([
            "text":       fullText,
            "x":          Double(box.minX),
            "y":          Double(box.minY),
            "w":          Double(box.width),
            "h":          Double(box.height),
            "confidence": conf,
          ])
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
      recognizeTextFromImage(at: imagePath, result)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
