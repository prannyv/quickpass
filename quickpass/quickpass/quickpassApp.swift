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
    
    @State private var isLoggedIn = false

    var body: some Scene {
        
        // Menu Bar Icon Setup
        // "doc.on.clipboard" gives you the classic clipboard symbol
        MenuBarExtra("QuickPass", systemImage: "doc.on.clipboard") {
            
            if isLoggedIn {
                            // Pass the binding ($isLoggedIn) so ContentView can log out
                            ContentView(isLoggedIn: $isLoggedIn)
                                .environmentObject(clipboardManager)
                                .frame(width: 400, height: 350)
                        } else {
                            // Pass the binding ($isLoggedIn) so LoginView can log in
                            LoginView(isLoggedIn: $isLoggedIn)
                                .frame(width: 400, height: 350)
                        }
                
        }
        // This style allows for interactive content (TextFields, Buttons, etc.)
        .menuBarExtraStyle(.window) 
    }
}
