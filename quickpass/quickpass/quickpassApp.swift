//
//  quickpassApp.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI

@main
struct quickpassApp: App {
    // 1. Initialize the data manager
    @StateObject private var clipboardManager = ClipboardManager()

    var body: some Scene {
        
        // PART 1: The "Dock" Window
        // This ensures that clicking the icon in the Dock actually opens a window.
        WindowGroup {
            ContentView()
                .environmentObject(clipboardManager)
                .frame(minWidth: 400, minHeight: 350)
                .navigationTitle("QuickPass Main Window")
        }
        
        // PART 2: The Menu Bar Icon
        // We use a Star icon + Text to force it to be visible.
        MenuBarExtra {
            // This is the little popover window attached to the tray icon
            ContentView()
                .environmentObject(clipboardManager)
                .frame(width: 400, height: 350)
        } label: {
            // A label with both text and icon is the safest way to ensure visibility
            Label("QP", systemImage: "star.fill")
        }
        .menuBarExtraStyle(.window)
    }
}