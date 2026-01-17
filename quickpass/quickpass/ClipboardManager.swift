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


// bryant model/algo CALL "v2CheckIsAPIKey"
import Foundation

// MARK: - Public API

/// Fast, heuristic "API key likeness" check.
/// Designed for ~instant evaluation on 1–50 char strings.
///
/// - Returns: true if the token looks like an API key / secret / token.
public func v2CheckIsAPIKey(_ raw: String) -> Bool {
    let s = v2SafeStrip(raw)
    let n = s.count
    if n == 0 { return false }
    if n > 256 { return true } // very long opaque tokens are almost always secrets

    // 1) Hard signals: known prefixes and strong shapes
    if v2HasKnownPrefix(s) {
        // Most vendor keys are long-ish; still allow short AWS access key id.
        if n >= 16 { return true }
    }

    if v2LooksLikeJWT(s) { return true }
    if v2LooksLikeHex(s) { return true }
    if v2LooksLikeBase64(s) { return true }

    // 2) Soft scoring (cheap)
    // For short strings, be conservative.
    if n < 10 { return false }

    let stats = v2CharStats(s)
    let digitRatio  = Double(stats.digits) / Double(n)
    let symbolRatio = Double(stats.symbols) / Double(n)
    let upperRatio  = Double(stats.upper)  / Double(n)
    let lowerRatio  = Double(stats.lower)  / Double(n)

    let variety = v2CharVarietyScore(hasLower: stats.lower > 0,
                                    hasUpper: stats.upper > 0,
                                    hasDigit: stats.digits > 0,
                                    hasSymbol: stats.symbols > 0)

    let entropy = v2ShannonEntropy(s) // bits/char, max ~log2(unique chars)
    let hasEquals = s.contains("=")

    // Weighted “key-likeness” score (tuneable).
    // Intent: catch opaque tokens; avoid normal words/filenames/ids.
    var score = 0.0

    // Length helps a lot
    if n >= 20 { score += 1.2 }
    if n >= 28 { score += 1.0 }
    if n >= 36 { score += 0.8 }

    // Character mix
    if variety >= 0.75 { score += 1.0 }
    else if variety >= 0.50 { score += 0.5 }

    // Entropy is a strong signal for "random-looking"
    if entropy >= 4.0 { score += 1.2 }          // quite random
    else if entropy >= 3.5 { score += 0.8 }
    else if entropy >= 3.0 { score += 0.4 }

    // Typical token shapes: some digits + some symbols or mixed case
    if digitRatio >= 0.15 { score += 0.3 }
    if symbolRatio >= 0.05 { score += 0.4 }
    if upperRatio >= 0.20 && lowerRatio >= 0.20 { score += 0.4 } // mixed case

    // Base64 padding hint (weak alone)
    if hasEquals && n >= 24 { score += 0.3 }

    // Penalties for “normal-looking”
    if symbolRatio == 0 && lowerRatio > 0.8 && digitRatio < 0.2 {
        // looks like a normal lowercase word or ID
        score -= 1.0
    }
    if s.contains(".") && !s.contains("-") && !s.contains("_") && n < 24 {
        // "filename.ext" vibe
        score -= 0.5
    }

    // Decision threshold:
    // - For 10–19 chars, require stronger evidence
    // - For 20+ chars, standard threshold
    let threshold = (n < 20) ? 2.7 : 2.2
    return score >= threshold
}

// MARK: - Known prefixes

private let v2KeywordPrefixes: [String] = [
    "AKIA",         // AWS access key id
    "ASIA",         // AWS temp
    "sk-",          // OpenAI/Stripe-ish
    "rk_",          // some vendors
    "pk_",          // Stripe public
    "xoxb-",        // Slack bot
    "xoxp-",        // Slack user
    "ghp_",         // GitHub
    "github_pat_",  // GitHub PAT
    "AIza",         // Google API key
]

private func v2HasKnownPrefix(_ s: String) -> Bool {
    for p in v2KeywordPrefixes {
        if s.hasPrefix(p) { return true }
    }
    return false
}

// MARK: - String cleanup

private func v2SafeStrip(_ s: String) -> String {
    // trim whitespace/newlines and a single layer of quotes
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasPrefix("\"") { t.removeFirst() }
    if t.hasSuffix("\"") { t.removeLast() }
    if t.hasPrefix("'")  { t.removeFirst() }
    if t.hasSuffix("'")  { t.removeLast() }
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Shape detectors

/// JWT: header.payload.signature, base64url-ish segments
private func v2LooksLikeJWT(_ s: String) -> Bool {
    let parts = s.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return false }

    for seg in parts {
        if seg.count < 8 { return false }
        for ch in seg.unicodeScalars {
            // base64url: A-Z a-z 0-9 - _
            if !(v2IsAlphaNum(ch) || ch == "-" || ch == "_") { return false }
        }
    }
    return true
}

/// Hex secret-ish: >= 24 chars, all hex
private func v2LooksLikeHex(_ s: String) -> Bool {
    guard s.count >= 24 else { return false }
    for ch in s.unicodeScalars {
        if !v2IsHex(ch) { return false }
    }
    return true
}

/// Base64-ish: >= 24 chars, only base64 chars, length multiple of 4
private func v2LooksLikeBase64(_ s: String) -> Bool {
    let n = s.count
    guard n >= 24 else { return false }
    guard n % 4 == 0 else { return false }

    for ch in s.unicodeScalars {
        if !v2IsBase64Char(ch) { return false }
    }
    return true
}

// MARK: - Numeric-ish features

private struct V2CharStats {
    var digits: Int = 0
    var upper: Int = 0
    var lower: Int = 0
    var symbols: Int = 0
}

/// Single pass stats (O(n))
private func v2CharStats(_ s: String) -> V2CharStats {
    var st = V2CharStats()
    for ch in s.unicodeScalars {
        if v2IsDigit(ch) { st.digits += 1 }
        else if v2IsUpper(ch) { st.upper += 1 }
        else if v2IsLower(ch) { st.lower += 1 }
        else { st.symbols += 1 }
    }
    return st
}

private func v2CharVarietyScore(hasLower: Bool, hasUpper: Bool, hasDigit: Bool, hasSymbol: Bool) -> Double {
    let count =
        (hasLower ? 1 : 0) +
        (hasUpper ? 1 : 0) +
        (hasDigit ? 1 : 0) +
        (hasSymbol ? 1 : 0)
    return Double(count) / 4.0
}

/// Shannon entropy in bits/character (O(n))
private func v2ShannonEntropy(_ s: String) -> Double {
    if s.isEmpty { return 0.0 }
    var counts: [UInt32: Int] = [:]
    counts.reserveCapacity(min(64, s.count))

    var n = 0
    for ch in s.unicodeScalars {
        let key = ch.value
        counts[key, default: 0] += 1
        n += 1
    }

    let dn = Double(n)
    var ent = 0.0
    ent.reserveCapacityIfAvailable() // no-op; keeps intent obvious

    for (_, c) in counts {
        let p = Double(c) / dn
        ent -= p * log2(p)
    }
    return ent
}

// MARK: - Character classification (fast, ASCII-focused)

private func v2IsDigit(_ ch: UnicodeScalar) -> Bool { ch.value >= 48 && ch.value <= 57 }          // 0-9
private func v2IsUpper(_ ch: UnicodeScalar) -> Bool { ch.value >= 65 && ch.value <= 90 }          // A-Z
private func v2IsLower(_ ch: UnicodeScalar) -> Bool { ch.value >= 97 && ch.value <= 122 }         // a-z
private func v2IsAlphaNum(_ ch: UnicodeScalar) -> Bool { v2IsDigit(ch) || v2IsUpper(ch) || v2IsLower(ch) }

private func v2IsHex(_ ch: UnicodeScalar) -> Bool {
    switch ch.value {
    case 48...57:  return true // 0-9
    case 65...70:  return true // A-F
    case 97...102: return true // a-f
    default: return false
    }
}

private func v2IsBase64Char(_ ch: UnicodeScalar) -> Bool {
    // base64: A-Z a-z 0-9 + / =
    if v2IsAlphaNum(ch) { return true }
    return ch == "+" || ch == "/" || ch == "="
}

// MARK: - Tiny helper to keep code clear (optional)

private extension Double {
    mutating func reserveCapacityIfAvailable() { /* intentionally empty */ }
}
