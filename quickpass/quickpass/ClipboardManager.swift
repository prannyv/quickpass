//
//  ClipboardManager.swift
//  quickpass
//
//  Created on 2026-01-17.
//

import SwiftUI
import AppKit
import Combine //login, logout, you have stoppped x vulnerabilities

/// Monitors the macOS clipboard and publishes changes.
/// Use as @StateObject in your app root or inject via .environmentObject()
final class ClipboardManager: ObservableObject {
//    var objectWillChange: ObservableObjectPublisher
    
    
    /// The current clipboard text (nil if clipboard is empty or contains non-text)
    @Published private(set) var currentText: String?
    
    /// Whether the current clipboard text appears to be an API key (based on entropy)
    @Published private(set) var isAPIKey: Bool = false
    
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
        isAPIKey = checkIsAPIKey(currentText)
    }
    
    /// Manually refresh the clipboard value
    func refresh() {
        updateClipboard()
    }
    
    // MARK: - API Key Detection
    
    /// Checks if the given text appears to be an API key based on entropy
    /// - Parameter text: The text to analyze
    /// - Returns: true if entropy is above 3.5, suggesting high randomness typical of API keys
    func checkIsAPIKey(_ text: String?) -> Bool {
        guard let text = text, !text.isEmpty else {
            return false
        }
        return calculateEntropy(text) > 3.5
    }
    
    /// Calculates the Shannon entropy of a string
    /// - Parameter text: The text to analyze
    /// - Returns: Entropy value in bits per character (0 = no randomness, ~4.7 for random alphanumeric)
    private func calculateEntropy(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }
        
        // Count frequency of each character
        var frequency: [Character: Int] = [:]
        for char in text {
            frequency[char, default: 0] += 1
        }
        
        let length = Double(text.count)
        
        // Calculate Shannon entropy: H = -Σ p(x) * log2(p(x))
        var entropy: Double = 0
        for count in frequency.values {
            let probability = Double(count) / length
            entropy -= probability * log2(probability)
        }
        
        return entropy
    }
}

