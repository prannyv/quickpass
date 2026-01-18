//
//  quickpassApp.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI
import Combine

@main
struct quickpassApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @StateObject private var onePassword = OnePasswordCLI()
    
    var body: some Scene {
        MenuBarExtra("QuickPass", systemImage: "doc.on.clipboard") {
            // The app now looks at the shared connection status
            if onePassword.isSignedIn {
                ContentView()
                    .environmentObject(clipboardManager)
                    .environmentObject(onePassword)
                    .frame(width: 400, height: 450)
            } else {
                LoginView()
                    .environmentObject(onePassword)
                    .environmentObject(clipboardManager)
                    .frame(width: 400, height: 450)
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: clipboardManager.isAPIKey) { newValue in
            // Fallback: trigger popup when isAPIKey changes to true
            // This handles the initial detection case
            if newValue && onePassword.isSignedIn {
                OnePasswordWindowManager.shared.showPopup(
                    clipboardManager: clipboardManager,
                    onePassword: onePassword
                )
            }
        }
    }
}

