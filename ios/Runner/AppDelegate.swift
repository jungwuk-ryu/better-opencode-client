import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let clipboardImageChannelName =
    "opencode_mobile_remote/clipboard_image"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    let didFinish = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    if let controller = window?.rootViewController as? FlutterViewController {
      configureClipboardImageChannel(binaryMessenger: controller.binaryMessenger)
    }
    return didFinish
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func configureClipboardImageChannel(
    binaryMessenger: FlutterBinaryMessenger
  ) {
    let channel = FlutterMethodChannel(
      name: clipboardImageChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "readClipboardImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.readClipboardImage())
    }
  }

  private func readClipboardImage() -> [String: Any]? {
    guard let image = UIPasteboard.general.image,
      let data = image.pngData()
    else {
      return nil
    }
    return [
      "bytes": FlutterStandardTypedData(bytes: data),
      "mimeType": "image/png",
      "filename": "pasted-image.png",
    ]
  }
}
