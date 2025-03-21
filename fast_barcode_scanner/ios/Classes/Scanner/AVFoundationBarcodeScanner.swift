import AVFoundation

typealias AVMetadataObjectBoundsConverter = @MainActor (AVMetadataObject) -> AVMetadataObject?

class AVFoundationBarcodeScanner: NSObject, BarcodeScanner, AVCaptureMetadataOutputObjectsDelegate {

  init(
    objectBoundsConverter: @escaping AVMetadataObjectBoundsConverter,
    resultHandler: @escaping ResultHandler
  ) {
    self.resultHandler = resultHandler
    self.objectBoundsConverter = objectBoundsConverter
  }

  var resultHandler: ResultHandler

  var objectBoundsConverter: AVMetadataObjectBoundsConverter

  var onDetection: (() -> Void)?

  private let output = AVCaptureMetadataOutput()
  private let metadataQueue = DispatchQueue(
    label: "fast_barcode_scanner.avfoundation_scanner.serial")
  private var _session: AVCaptureSession?
  private var _symbologies = [String]()
  private var isPaused = false

  var symbologies: [String] {
    get { _symbologies }
    set {
      _symbologies = newValue

      // This will just ignore all unsupported types
      output.metadataObjectTypes = newValue.compactMap { avMetadataObjectTypes[$0] }

      // UPC-A is reported as EAN-13
      if newValue.contains("upcA") && !output.metadataObjectTypes.contains(.ean13) {
        output.metadataObjectTypes.append(.ean13)
      }

      // Report to the user if any types are not supported
      if output.metadataObjectTypes.count != newValue.count {
        let unsupportedTypes = newValue.filter { avMetadataObjectTypes[$0] == nil }
        print("WARNING: Unsupported barcode types selected: \(unsupportedTypes)")
      }
    }
  }

  var session: AVCaptureSession? {
    get { _session }
    set {
      _session = newValue
      if let session = newValue, session.canAddOutput(output), !session.outputs.contains(output) {
        session.addOutput(output)
      }
    }
  }

  func start() {
    output.setMetadataObjectsDelegate(self, queue: metadataQueue)
  }

  func stop() {
    output.setMetadataObjectsDelegate(nil, queue: nil)
  }
    
    @MainActor
  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {

    var scannedCodes: [[Any?]] = []

    for metadata in metadataObjects {
      guard
        let readableCode = metadata as? AVMetadataMachineReadableCodeObject,
        let boundingBox = objectBoundsConverter(readableCode)?.bounds,
        var type = flutterMetadataObjectTypes[readableCode.type],
        var value = readableCode.stringValue
    else { continue }
        
      // Fix UPC-A, see https://developer.apple.com/library/archive/technotes/tn2325/_index.html#//apple_ref/doc/uid/DTS40013824-CH1-IS_UPC_A_SUPPORTED_
      if readableCode.type == .ean13 {
        if value.hasPrefix("0") {
          // UPC-A
          guard symbologies.contains("upcA") else { continue }
          type = "upcA"
          value.removeFirst()
        } else {
          // EAN-13
          guard symbologies.contains(type) else { continue }
        }
      }

      scannedCodes.append([
        type, value, nil, boundingBox.minX, boundingBox.minY, boundingBox.maxX, boundingBox.maxY,
      ])
    }

    onDetection?()

    resultHandler(scannedCodes)
  }
}
