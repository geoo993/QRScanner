//
//  QRScannerApp.swift
//  QRScanner
//
//  Created by George Quentin on 23/10/2024.
//

import SwiftUI

@main
struct QRScannerApp: App {
    var body: some Scene {
        WindowGroup {
            QRScreen(viewModel: .init())
                .preferredColorScheme(.light)
        }
    }
}
