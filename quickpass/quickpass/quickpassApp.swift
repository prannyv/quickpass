//
//  quickpassApp.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI

@main
struct quickpassApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    // The ONLY instance of the 1Password connection
    @StateObject private var onePassword = OnePasswordCLI()
    
    var body: some Scene {
        MenuBarExtra("QuickPass", systemImage: "doc.on.clipboard") {
            // The app now looks at the shared connection status
            if onePassword.isSignedIn {
                ContentView()
                    .environmentObject(clipboardManager)
                    .environmentObject(onePassword) // Share the connection
                    .frame(width: 400, height: 450)
            } else {
                LoginView()
                    .environmentObject(onePassword) // Share the connection
                    .frame(width: 400, height: 450)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

