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
        
        // Menu Bar Icon Setup
        // "doc.on.clipboard" gives you the classic clipboard symbol
        MenuBarExtra("QuickPass", systemImage: "doc.on.clipboard") {
            
            // The Popover Window Content
            ContentView()
                .environmentObject(clipboardManager)
                .frame(width: 400, height: 350)
                
        }
        // This style allows for interactive content (TextFields, Buttons, etc.)
        .menuBarExtraStyle(.window) 
    }
}