import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let clipboardImageChannelName =
    "opencode_mobile_remote/clipboard_image"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureClipboardImageChannel(for: flutterViewController)

    super.awakeFromNib()
  }

  private func configureClipboardImageChannel(
    for flutterViewController: FlutterViewController
  ) {
    let channel = FlutterMethodChannel(
      name: clipboardImageChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "readClipboardImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Self.readClipboardImage())
    }
  }

  private static func readClipboardImage() -> [String: Any]? {
    guard let image = NSImage(pasteboard: NSPasteboard.general),
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
    else {
      return nil
    }
    return [
      "bytes": FlutterStandardTypedData(bytes: pngData),
      "mimeType": "image/png",
      "filename": "pasted-image.png",
    ]
  }
}
