import Flutter
import MobileCoreServices

public class FileSaveDirectoryPlugin: NSObject, FlutterPlugin {
  private var pendingFlutterResult: FlutterResult?
  private var tempFileURL: URL?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.filesave/file_save_directory", binaryMessenger: registrar.messenger())
    let instance = FileSaveDirectoryPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "saveFileWithPicker":
      guard let args = call.arguments as? [String: Any],
            let fileName = args["fileName"] as? String,
            let fileBytes = args["fileBytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        return
      }
      saveFileWithPicker(fileName: fileName, fileData: fileBytes.data, result: result)

    case "createFolder":
      guard let args = call.arguments as? [String: Any],
            let folderName = args["folderName"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing folder name", details: nil))
        return
      }
      createFolder(folderName: folderName, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func saveFileWithPicker(fileName: String, fileData: Data, result: @escaping FlutterResult) {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    do {
      try fileData.write(to: tempURL)
      self.tempFileURL = tempURL
      self.pendingFlutterResult = result
    } catch {
      result(FlutterError(code: "FILE_WRITE_FAILED", message: "Could not write temp file", details: error.localizedDescription))
      return
    }

    let documentPicker = UIDocumentPickerViewController(url: tempURL, in: .exportToService)
    documentPicker.delegate = self
    documentPicker.allowsMultipleSelection = false

    if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
      rootViewController.present(documentPicker, animated: true, completion: nil)
    } else {
      result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not present document picker", details: nil))
    }
  }

  private func createFolder(folderName: String, result: @escaping FlutterResult) {
    let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
    documentPicker.delegate = self
    documentPicker.allowsMultipleSelection = false

    self.pendingFlutterResult = result

    if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
      rootViewController.present(documentPicker, animated: true, completion: nil)
    } else {
      result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not present document picker", details: nil))
    }
  }
}

// MARK: - UIDocumentPickerDelegate
extension FileSaveDirectoryPlugin: UIDocumentPickerDelegate {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard urls.first != nil else {
      pendingFlutterResult?(FlutterError(code: "NO_URL_SELECTED", message: "No URL selected", details: nil))
      cleanup()
      return
    }

    // When using .exportToService, iOS copies the file to the chosen destination
    // and calls this delegate with the URL of the already-saved copy.
    // There is nothing left to move – just clean up the temp file and report success.
    if let tempURL = tempFileURL {
      try? FileManager.default.removeItem(at: tempURL)
      pendingFlutterResult?(true)
    } else {
      // This was a folder creation request
      pendingFlutterResult?(true)
    }

    cleanup()
  }

  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingFlutterResult?(FlutterError(code: "CANCELLED", message: "User cancelled the operation", details: nil))
    cleanup()
  }

  private func cleanup() {
    pendingFlutterResult = nil
    tempFileURL = nil
  }
}