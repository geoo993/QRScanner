import SwiftUI
import AVFoundation

// https://www.appcoda.com/swiftui-qr-code-scanner-app/
// https://www.createwithswift.com/reading-qr-codes-and-barcodes-with-the-vision-framework/
// https://konradpiekos93.medium.com/detect-when-the-views-frame-changes-f8428f3421a5

enum ScanningError: Error, Equatable {
    case captureDeviceError
}

enum ScanningState: Equatable {
    case undetermined
    case loaded(String)
    case error(ScanningError)
}

class ResizableView: UIView {
    private weak var delegate: AVCaptureMetadataOutputObjectsDelegate?
    private let objectTypes: [AVMetadataObject.ObjectType]
    private var captureSession: AVCaptureSession?
    
    init(
        objectTypes: [AVMetadataObject.ObjectType],
        delegate: AVCaptureMetadataOutputObjectsDelegate?
    ) {
        self.objectTypes = objectTypes
        self.delegate = delegate
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) {
            layer.frame = bounds
            print("GRADIENT FRAME", layer.frame)
        }
        setNeedsDisplay()
        
        print("Controller FRAME:", frame)
        print("Controller BOUNDS:", bounds)
        print("Controller PREFERRED SIZE:", layer.preferredFrameSize())
    }

    func setupSession() throws(ScanningError) {
        // Get an instance of the AVCaptureDeviceInput class using the previous device object.
        guard
            let videoCaptureDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
        else {
            throw ScanningError.captureDeviceError
        }

        // Set the input device on the capture session.
        let captureSession = AVCaptureSession()
        captureSession.addInput(videoInput)

        // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)

        // Set delegate and use the default dispatch queue to execute the call back
        captureMetadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = objectTypes

        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = frame
        layer.addSublayer(previewLayer)
        
        self.captureSession = captureSession
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

struct QRScannerView: UIViewRepresentable {
    @Binding private(set) var state: ScanningState
    private let objectTypes: [AVMetadataObject.ObjectType]
    
    init(state: Binding<ScanningState>, objectTypes: [AVMetadataObject.ObjectType]) {
        self._state = state
        self.objectTypes = objectTypes
    }

    func makeUIView(context: Context) -> UIView {
        let myVuew = ResizableView(objectTypes: objectTypes, delegate: context.coordinator)
        
        do throws(ScanningError) {
            try myVuew.setupSession()
            myVuew.startRunning()
        } catch {
            state = .error(error)
        }
        return myVuew
    }
    
    func updateUIView(_ uiViewController: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 3. Implementing the Coordinator class
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private var parent: QRScannerView
        
        init(_ parent: QRScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            print("NEW OUTPUT")
            // Check if the metadataObjects array is not nil and it contains at least one object.
            if metadataObjects.count == 0 {
                parent.state = .loaded("No QR code detected")
                return
            }

            // Get the metadata objects.
            guard let results = metadataObjects as? [AVMetadataMachineReadableCodeObject] else { return }

            // Get value of specified types
            for value in results {
                if parent.objectTypes.contains(value.type), let result = value.stringValue {
                    Task {
                        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                        self.parent.state = .loaded(result)
                    }
                    // Optionally, stop scanning after first detection
//                     self.parent.captureSession.stopRunning()
                }
            }
        }
    }
}
