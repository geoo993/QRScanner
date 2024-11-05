import SwiftUI
import AVFoundation

// https://www.appcoda.com/swiftui-qr-code-scanner-app/
// https://www.createwithswift.com/reading-qr-codes-and-barcodes-with-the-vision-framework/
// https://konradpiekos93.medium.com/detect-when-the-views-frame-changes-f8428f3421a5

enum ScanningError: Error {
    case cameraAccessError
    case captureDeviceError(Error)
}

enum ScanningState: Equatable {
    case undetermined
    case scanning
    case scannedQr(String)
    case error(String)
    case unknownQr
}

class QRScannerRepresentableView: UIView {
    private var isValid: (String) -> Bool
    private var captureSession: AVCaptureSession?
    private let objectTypes: [AVMetadataObject.ObjectType]
    private let result: (ScanningState) -> Void
    
    init(
        objectTypes: [AVMetadataObject.ObjectType],
        isValid: @escaping (String) -> Bool,
        result: @escaping (ScanningState) -> Void
    ) {
        self.objectTypes = objectTypes
        self.isValid = isValid
        self.result = result
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) {
            layer.frame = bounds
//            print("GRADIENT FRAME", layer.frame)
        }
        setNeedsDisplay()
        
//        print("Controller FRAME:", frame)
//        print("Controller BOUNDS:", bounds)
//        print("Controller PREFERRED SIZE:", layer.preferredFrameSize())
    }

    func setupSession() throws(ScanningError) {
        // Get an instance of the AVCaptureDeviceInput class using the previous device object.
        guard let videoCaptureDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            )
        else { throw ScanningError.cameraAccessError }
        
        do {
            self.captureSession = try createSession(from: videoCaptureDevice)
        } catch {
            throw ScanningError.captureDeviceError(error)
        }
    }
    
    private func createSession(from device: AVCaptureDevice) throws -> AVCaptureSession {
        let videoInput = try AVCaptureDeviceInput(device: device)

        // Set the input device on the capture session.
        let captureSession = AVCaptureSession()
        captureSession.addInput(videoInput)

        // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)

        // Set delegate and use the default dispatch queue to execute the call back
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = objectTypes

        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = frame
        layer.addSublayer(previewLayer)

        return captureSession
    }
    
    func startRunning() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }
    
    func stopRunning() {
        captureSession?.stopRunning()
    }
}

extension QRScannerRepresentableView: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            return result(.scanning)
        }

        // Get the metadata objects.
        guard let objects = metadataObjects as? [AVMetadataMachineReadableCodeObject] else {
            return
        }

        // Get value of specified types
        for object in objects {
            if objectTypes.contains(object.type), let content = object.stringValue {
                if isValid(content) {
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                    result(.scannedQr(content))
                    
                    // Optionally, stop scanning after first detection
                    captureSession?.stopRunning()
                } else {
                    result(.unknownQr)
                }
            }
        }
    }
}

struct QRScannerView: UIViewRepresentable {
    private let objectTypes: [AVMetadataObject.ObjectType]
    private let isValid:(String) -> Bool
    private let result: (ScanningState) -> Void
    
    init(
        state: Binding<ScanningState>,
        objectTypes: [AVMetadataObject.ObjectType] = [.qr],
        isValid: @escaping (String) -> Bool,
        result: @escaping (ScanningState) -> Void
    ) {
        self.objectTypes = objectTypes
        self.isValid = isValid
        self.result = result
    }

    func makeUIView(context: Context) -> UIView {
        let view = QRScannerRepresentableView(
            objectTypes: objectTypes,
            isValid: isValid,
            result: result
        )
        do throws(ScanningError) {
            try view.setupSession()
            view.startRunning()
            result(.scanning)
        } catch {
            result(.error(error.localizedDescription))
        }
        return view
    }
    
    func updateUIView(_ uiViewController: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {}
}
