//
//  ContentView.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Removed @Query and modelContext as we are no longer managing the list of items
    @EnvironmentObject var clipboardManager: ClipboardManager

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                
                // Section 1: Content Display
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Clipboard Text:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("No text on clipboard", text: Binding(
                        get: { clipboardManager.currentText ?? "" },
                        set: { _ in }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true) // Read-only
                }
                
                // Section 2: Logic Check
                VStack(alignment: .leading, spacing: 4) {
                    Text("Is API Key:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("", text: Binding(
                        get: { String(clipboardManager.isAPIKey) },
                        set: { _ in }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true) // Read-only
                }
                
                Spacer() // Pushes content to the top
            }
            .padding()
            .navigationTitle("QuickPass") // Added a title for context
        }
    }
}

#Preview {
    ContentView()
        // We still inject the environment object for the preview to work
        .environmentObject(ClipboardManager())
}