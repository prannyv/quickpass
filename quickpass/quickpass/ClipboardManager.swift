//
//  ClipboardManager.swift
//  quickpass
//
//  Created on 2026-01-17.
//

import SwiftUI
import AppKit
import Combine

/// Monitors the macOS clipboard and publishes changes.
/// Use as @StateObject in your app root or inject via .environmentObject()
final class ClipboardManager: ObservableObject {
//    var objectWillChange: ObservableObjectPublisher
    
    
    /// The current clipboard text (nil if clipboard is empty or contains non-text)
    @Published private(set) var currentText: String?
    
    /// The last change count from NSPasteboard (used to detect changes)
    private var lastChangeCount: Int = 0
    
    /// Timer for polling clipboard changes
    private var timer: Timer?
    
    /// Polling interval in seconds
    private let pollInterval: TimeInterval
    
    init(pollInterval: TimeInterval = 0.5) {
        self.pollInterval = pollInterval
        // Get initial clipboard state
        updateClipboard()
        // Start monitoring
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    /// Starts monitoring the clipboard for changes
    func startMonitoring() {
        guard timer == nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkForChanges()
            }
        }
    }
    
    /// Stops monitoring the clipboard
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Checks if the clipboard has changed and updates if necessary
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        
        // Only update if the change count has changed
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            updateClipboard()
        }
    }
    
    /// Updates the currentText from the clipboard
    private func updateClipboard() {
        let pasteboard = NSPasteboard.general
        lastChangeCount = pasteboard.changeCount
        currentText = pasteboard.string(forType: .string)
    }
    
    /// Manually refresh the clipboard value
    func refresh() {
        updateClipboard()
    }
}

