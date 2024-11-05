import SwiftUI
import VisionKit
import Foundation
import AVFoundation

struct QRScreen: View {
    enum CameraPermissionStatus: Equatable {
        case undetermined
        case granted
        case denied
    }
    
    enum Event: Hashable {
        case didAppear
    }

    @StateObject var viewModel: ViewModel
    @State private var currentEvent: Event?
    
    public init(viewModel: ViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.currentEvent = currentEvent
    }

    public var body: some View {
        NavigationView {
            ContentView(
                permission: viewModel.permission,
                event: { currentEvent = $0 }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: currentEvent) {
            guard let currentEvent else { return }
            await viewModel.handle(event: currentEvent)
            self.currentEvent = nil
        }
        .onAppear {
            currentEvent = .didAppear
        }
    }
}

extension QRScreen {
    @MainActor
    public class ViewModel: ObservableObject {
        @Published var permission: CameraPermissionStatus = .undetermined

        func handle(event: Event) async {
            switch event {
            case .didAppear:
                await requestPermission()
            }
        }
        
        private func requestPermission() async {
            let status =  AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                permission = .granted
            case .notDetermined:
                let isGranted = await AVCaptureDevice.requestAccess(for: .video)
                permission = isGranted ? .granted : .denied
            case .denied, .restricted:
                permission = .denied
            @unknown default:
                permission = .denied
            }
        }
    }
}

extension QRScreen {
    struct ContentView: View {
        @Environment(\.openURL) var openURL
        @State private var state: ScanningState = .undetermined
        @State private var isShowingScanner = true
        @State private var isAlertPresented = false
        private let permission: CameraPermissionStatus
        private let event: (Event) -> Void

        init(permission: CameraPermissionStatus, event: @escaping (Event) -> Void) {
            self.permission = permission
            self.event = event
        }

        var body: some View {
            contentView
                .onChange(of: state) { value in
                    switch value {
                    case .undetermined:
                        print("Capturing Undertermined")
                    case .scanning:
                        print("we are looking around to scan")
                    case let .scannedQr(result):
                        print("We found result:\(result)")
                    case .unknownQr:
                        print("We found an invalid QR")
                    case let .error(error):
                        print(error)
                    }
                }
                .onChange(of: permission) { value in
                    isAlertPresented = value == .denied
                    switch value {
                    case .undetermined:
                        print("CAMERA NOT DETERMINED")
                    case .granted:
                        print("CAMERA AUTHORISED")
                    case .denied:
                        print("CAMERA DENIED AND RESTRICTED")
                    }
                }
                .alert("Allow Dojo to access your camera", isPresented: $isAlertPresented) {
                    Button("Cancel", role: .cancel) {
                        // close flow
                    }
                    Button("Go to settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                } message: {
                    Text("To use this feature, you’ll need to allow the Dojo app to access your camera from your device Settings.")
                }
        }

        @ViewBuilder
        var contentView: some View {
            VStack {
                switch permission {
                case .undetermined:
                    Rectangle()
                        .fill(Color.black)
                        .overlay {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.white)
                            
                        }
                    
                case .granted:
                    scanningContentView
                case .denied:
                    Rectangle()
                        .fill(Color.black)
                    // add alert
                }
                
                bottomView
            }
        }

        @ViewBuilder
        var scanningContentView: some View {
            ZStack(alignment: .bottom) {
                QRScannerView(
                    state: $state,
                    objectTypes: [.qr],
                    isValid: {
                        $0 == "https://account.dojo.tech/card-machine-activation"
                    }
                ) { result in
                    Task {
                        state = result
                    }
                }
                ZStack(alignment: .center) {
                    Rectangle() // destination
                        .fill(Color.black.opacity(0.3))
                    RoundedRectangle(cornerRadius: 25)
                        .frame(width: 279, height: 269)
                        .blendMode(.destinationOut)
                    Image("corners")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(roundedEdgesColor)
                        .frame(width: 280, height: 270)
                }
                .compositingGroup()
                .animation(.easeInOut, value: roundedEdgesColor)
                
                footnoteView
                    .animation(.easeInOut, value: state)
            }
        }
        
        @ViewBuilder
        private var footnoteView: some View {
            if state == .unknownQr {
                Text("Scan a Dojo card machine QR code")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
            }
        }
        
        @ViewBuilder
        private var bottomView: some View {
            VStack(alignment: .center, spacing: 8) {
                Text("Scan QR code")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Scan the QR code appearing on the card machine to activate it. Make sure you’re logged in to the correct account.")
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.gray)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 209)
        }

        private var roundedEdgesColor: Color {
            switch state {
            case .undetermined, .scanning:
                return .white
            case .scannedQr:
                return .green
            case .unknownQr, .error:
                return .red
            }
        }
    }
}

#Preview {
    NavigationView {
        QRScreen.ContentView(permission: .granted, event: { _ in })
    }
}
