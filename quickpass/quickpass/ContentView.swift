//
//  ContentView.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI
import SwiftData
import AppKit

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
                
                // Section 3: The Popup Trigger
                // This calls PopupWindowManager, which lives in your OTHER file (SaveProposalView.swift)
                if clipboardManager.isAPIKey {
                    Button(action: {
                        PopupWindowManager.shared.showSaveDialog()
                    }) {
                        Label("Save to 1Password", systemImage: "lock.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                } else {
                    Button(action: {
                        PopupWindowManager.shared.showSaveDialog()
                    }) {
                        Text("Test Popup Window")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer() // Pushes content to the top
                
                // Footer Controls
                HStack {
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear") {
                        NSPasteboard.general.clearContents()
                        clipboardManager.refresh()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("QuickPass")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardManager())
}
