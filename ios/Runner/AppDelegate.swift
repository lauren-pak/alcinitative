import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VideoPrep") {
      VideoPrep.register(messenger: registrar.messenger())
    }
  }
}

/// Prepares a picked video for upload (called from `lib/services/media_prep.dart`).
///
/// Re-exports it as a 720p MP4 with Apple's `forSharing` metadata filter, which
/// removes location and other personal metadata, and writes a JPEG thumbnail.
/// Protects young athletes from revealing where a video was filmed.
enum VideoPrep {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "athlete_app/video_prep", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "prepare",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      prepare(path: path, result: result)
    }
  }

  static func prepare(path: String, result: @escaping FlutterResult) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard
      let export = AVAssetExportSession(
        asset: asset, presetName: AVAssetExportPreset1280x720)
    else {
      result(FlutterError(code: "export", message: "Can't process this video", details: nil))
      return
    }
    let dir = FileManager.default.temporaryDirectory
    let id = UUID().uuidString
    let output = dir.appendingPathComponent("\(id).mp4")
    export.outputURL = output
    export.outputFileType = .mp4
    export.shouldOptimizeForNetworkUse = true
    // Drop location and personal details; keep nothing else either.
    export.metadataItemFilter = AVMetadataItemFilter.forSharing()
    export.metadata = []

    export.exportAsynchronously {
      guard export.status == .completed else {
        let message = export.error?.localizedDescription ?? "Video export failed"
        DispatchQueue.main.async {
          result(FlutterError(code: "export", message: message, details: nil))
        }
        return
      }
      let exported = AVURLAsset(url: output)
      let generator = AVAssetImageGenerator(asset: exported)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 1280, height: 1280)
      let thumbnail = dir.appendingPathComponent("\(id)_thumb.jpg")
      var width = 0
      var height = 0
      let time = CMTime(seconds: 0.2, preferredTimescale: 600)
      if let frame = try? generator.copyCGImage(at: time, actualTime: nil) {
        width = frame.width
        height = frame.height
        // A fresh JPEG from pixels only: carries no metadata.
        try? UIImage(cgImage: frame).jpegData(compressionQuality: 0.8)?.write(to: thumbnail)
      }
      let durationMs = Int(CMTimeGetSeconds(exported.duration) * 1000)
      DispatchQueue.main.async {
        result([
          "path": output.path,
          "thumbnailPath": thumbnail.path,
          "width": width,
          "height": height,
          "durationMs": durationMs,
        ])
      }
    }
  }
}
