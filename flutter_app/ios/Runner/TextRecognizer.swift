import Flutter
import ImageIO
import UIKit
import Vision

/// On-device OCR for the box-title scanner, backed by Apple Vision.
///
/// Channel `churternplay/text_recognition`, method `recognize({path})` returns
/// `{imageWidth, imageHeight, lines: [{text, left, top, width, height}]}` with
/// box coordinates normalised to 0–1 from the top-left of the upright image —
/// the same shape the Android (ML Kit) implementation returns.
final class TextRecognizer {
  static let channelName = "churternplay/text_recognition"

  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "churternplay.text_recognition", qos: .userInitiated)

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognize" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
      result(FlutterError(code: "bad_args", message: "Missing image path", details: nil))
      return
    }

    queue.async {
      let response: Any
      do {
        response = try Self.recognize(path: path)
      } catch {
        response = FlutterError(code: "recognition_failed", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(response) }
    }
  }

  private static func recognize(path: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw NSError(domain: "TextRecognizer", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not read image"])
    }

    // Respect EXIF orientation so boxes come back relative to the upright image.
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
    let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    try handler.perform([request])

    let lines: [[String: Any]] = (request.results ?? []).compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      // Vision boxes are normalised with a bottom-left origin; flip to top-left.
      let box = observation.boundingBox
      return [
        "text": candidate.string,
        "left": Double(box.minX),
        "top": Double(1 - box.maxY),
        "width": Double(box.width),
        "height": Double(box.height),
      ]
    }

    let rotated = [.left, .leftMirrored, .right, .rightMirrored].contains(orientation)
    return [
      "imageWidth": rotated ? image.height : image.width,
      "imageHeight": rotated ? image.width : image.height,
      "lines": lines,
    ]
  }
}
