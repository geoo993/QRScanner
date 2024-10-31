import SwiftUI
import VisionKit
import Foundation
import AVFoundation

struct QRScreen: View {
    enum CameraPermissionStatus {
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
                print("CAMERA AUTHORISED")
                permission = .granted
            case .notDetermined:
                print("CAMERA NOT DETERMINED")
                let isGranted = await AVCaptureDevice.requestAccess(for: .video)
                permission = isGranted ? .granted : .denied
            case .denied, .restricted:
                permission = .denied
                print("CAMERA DENIED OR RESTRICTED")
                
            @unknown default:
                permission = .denied
                print("CAMERA ACCESS UNKNOWN")
            }
        }
    }
}

extension QRScreen {
    struct ContentView: View {
        @State private var state: ScanningState = .undetermined
        @State private var isShowingScanner = true
        @State private var scannedString: String = "Scanned your QR code"
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
                    case let .loaded(result):
                        print("Result Found")
                        scannedString = result
                    case let .error(error):
                        print(error.localizedDescription)
                    }
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
                }
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
                .background(Color.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 209)
            }
        }
        
        @ViewBuilder
        var scanningContentView: some View {
            ZStack(alignment: .bottom) {
                QRScannerView(state: $state, objectTypes: [.qr])
                ZStack(alignment: .center) {
                    Rectangle() // destination
                        .fill(Color.red.opacity(0.3))
                    RoundedRectangle(cornerRadius: 25) // source
                        .frame(width: 279, height: 269)
                        .blendMode(.destinationOut)
                    Image("corners")
                        .resizable()
                        .renderingMode(.template)
//                        .aspectRatio(contentMode: .fit)
                        .frame(width: 280, height: 270)
                }
                .compositingGroup()
                .foregroundStyle(Color.white)
                
                Text(scannedString)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
            }
        }
    }
}

#Preview {
    NavigationView {
        QRScreen.ContentView(permission: .granted, event: { _ in })
    }
}
