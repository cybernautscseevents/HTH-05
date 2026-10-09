import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var documentPickerResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "saathi/discharge_document",
      binaryMessenger: engineBridge.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickDocument" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self, self.documentPickerResult == nil else {
        result(FlutterError(code: "picker_busy", message: "A document picker is already open", details: nil))
        return
      }
      self.documentPickerResult = result
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
        .pdf, .jpeg, .png
      ])
      picker.delegate = self
      picker.allowsMultipleSelection = false
      self.window?.rootViewController?.present(picker, animated: true)
    }
  }
}

extension AppDelegate: UIDocumentPickerDelegate {
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = documentPickerResult else { return }
    documentPickerResult = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
    }
    do {
      let bytes = try Data(contentsOf: url)
      result(["name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: bytes)])
    } catch {
      result(FlutterError(code: "read_failed", message: "Unable to read the selected document", details: error.localizedDescription))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = documentPickerResult
    documentPickerResult = nil
    result?(nil)
  }
}
