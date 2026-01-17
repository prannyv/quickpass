//
//  SaveProposalView.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI
import AppKit

struct SaveProposalView: View {
    // We use a callback to tell the parent window to close itself
    var onClose: () -> Void
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            VStack(spacing: 5) {
                Text("API Key Detected")
                    .font(.headline)
                Text("Do you want to save this to 1Password?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 15) {
                Button("Cancel") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save to 1Password") {
                    onSave()
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(25)
        .frame(width: 300, height: 200)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
    }
}

// Helper to make the background look like a native macOS popup
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}


class PopupWindowManager {
    static let shared = PopupWindowManager()
    private var popupWindow: NSPanel?
    
    func showSaveDialog() {
        // Prevent opening multiple instances
        if popupWindow != nil {
            popupWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create a new floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // --- KEY "STICKY" BEHAVIOR ---
        // 1. .canJoinAllSpaces: Follows you if you swipe desktops
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // 2. .floating: Stays on top of other apps
        panel.level = .floating
        
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false // We handle cleanup manually
        
        // Setup the SwiftUI content
        let contentView = SaveProposalView(
            onClose: { [weak self] in
                self?.closeWindow()
            },
            onSave: {
                print("Saving to 1Password...") // Logic goes here
            }
        )
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center() // Centers on the currently active screen
        
        self.popupWindow = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        popupWindow?.close()
        popupWindow = nil
    }
}
