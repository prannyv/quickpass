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
    
    /// The current clipboard text (nil if clipboard is empty or contains non-text)
    @Published private(set) var currentText: String?
    
    /// Whether the current clipboard text appears to be an API key
    @Published private(set) var isAPIKey: Bool = false
    
    /// The last change count from NSPasteboard
    private var lastChangeCount: Int = 0
    
    /// Timer for polling clipboard changes
    private var timer: Timer?
    
    /// Polling interval in seconds
    private let pollInterval: TimeInterval
    
    init(pollInterval: TimeInterval = 0.5) {
        self.pollInterval = pollInterval
        
        // Get initial clipboard state (but don't trigger popup on launch)
        let pasteboard = NSPasteboard.general
        self.lastChangeCount = pasteboard.changeCount
        let initialText = pasteboard.string(forType: .string)
        self.currentText = initialText
        self.isAPIKey = checkIsAPIKey(initialText)
        
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
        
        let newText = pasteboard.string(forType: .string)
        currentText = newText
        
        // Check if it is a key
        let detected = checkIsAPIKey(newText)
        isAPIKey = detected
        
        // --- NEW TRIGGER LOGIC ---
        // If an API key is found, immediately show the popup.
        // We use DispatchQueue.main to ensure UI updates happen safely.
        if detected {
            print("API Key Detected! Triggering Popup...")
            DispatchQueue.main.async {
                // Calls the Window Manager shared instance (defined in ContentView.swift)
                OnePasswordWindowManager.shared.showProposal()
            }
        }
    }
    
    /// Manually refresh the clipboard value
    func refresh() {
        updateClipboard()
    }
    
    // MARK: - API Key Detection
    
    func checkIsAPIKey(_ text: String?) -> Bool {
        guard let text = text, !text.isEmpty else {
            return false
        }
        return v2CheckIsAPIKey(text)
    }
}


// MARK: - API Key Detection Algorithm (Bryant Model)

import Foundation

/// Fast, heuristic "API key likeness" check.
public func v2CheckIsAPIKey(_ raw: String) -> Bool {
    let s = v2SafeStrip(raw)
    let n = s.count
    
    // Basic bounds
    if n < 10 { return false }
    if n > 256 { return false }
    
    // Stage 0: Quick rejects
    if v2QuickReject(s, length: n) {
        return false
    }
    
    // Stage 1: Hard signals
    if let hardResult = v2CheckHardSignals(s, length: n) {
        return hardResult
    }
    
    // Stage 2: Soft scoring
    return v2SoftScore(s, length: n)
}

// MARK: - Stage 0: Quick Rejects

private func v2QuickReject(_ s: String, length n: Int) -> Bool {
    let lower = s.lowercased()
    
    let falsePositives = [
        "example", "test", "sample", "placeholder", "your_key_here",
        "password", "secret", "token", "apikey", "api_key",
        "lorem", "ipsum", "dummy", "mock", "fake",
        "xxxxxxxxxx", "123456789", "undefined", "null"
    ]
    
    for pattern in falsePositives {
        if lower.contains(pattern) { return true }
    }
    
    if s.contains(" ") && n > 15 { return true }
    if v2HasExcessiveRepetition(s) { return true }
    if v2LooksLikeURL(lower) { return true }
    if lower.contains("@") && lower.contains(".") { return true }
    if s.filter({ $0 == "/" }).count >= 2 { return true }
    
    return false
}

// MARK: - Stage 1: Hard Signals

private func v2CheckHardSignals(_ s: String, length n: Int) -> Bool? {
    if v2HasKnownPrefix(s) {
        let minLengths: [String: Int] = [
            "AKIA": 20, "ASIA": 20, "sk_live_": 32, "sk_test_": 32,
            "pk_live_": 32, "pk_test_": 32, "xoxb-": 50, "xoxp-": 50,
            "ghp_": 40, "gho_": 40, "ghu_": 40, "ghs_": 40,
            "github_pat_": 82, "AIza": 39,
        ]
        
        for (prefix, minLen) in minLengths {
            if s.hasPrefix(prefix) && n >= minLen { return true }
        }
        if n >= 16 { return true }
    }
    
    if v2LooksLikeJWT(s) && n >= 100 { return true }
    if v2LooksLikeHex(s) && n >= 32 && n <= 128 { return true }
    if v2LooksLikeBase64(s) && n >= 32 && n % 4 == 0 {
        let hasDigits = s.contains(where: { $0.isNumber })
        let hasSymbols = s.contains("+") || s.contains("/") || s.contains("=")
        if hasDigits || hasSymbols { return true }
    }
    
    let secretDomains = [
        ".apps.googleusercontent.com", ".firebaseapp.com", ".amazoncognito.com",
        ".onmicrosoft.com", ".azurewebsites.net", ".cloudapp.azure.com",
        ".supabase.co", ".vercel.app", ".netlify.app", ".herokuapp.com",
        ".awsapps.com", ".okta.com", ".auth0.com"
    ]
    
    let lower = s.lowercased()
    for domain in secretDomains {
        if lower.hasSuffix(domain) || lower.contains(domain) { return true }
    }
    
    return nil
}

// MARK: - Stage 2: Soft Scoring

private func v2SoftScore(_ s: String, length n: Int) -> Bool {
    let stats = v2CharStats(s)
    let digitRatio  = Double(stats.digits) / Double(n)
    let symbolRatio = Double(stats.symbols) / Double(n)
    let upperRatio  = Double(stats.upper)  / Double(n)
    let lowerRatio  = Double(stats.lower)  / Double(n)
    
    let variety = v2CharVarietyScore(hasLower: stats.lower > 0,
                                     hasUpper: stats.upper > 0,
                                     hasDigit: stats.digits > 0,
                                     hasSymbol: stats.symbols > 0)
    
    let entropy = v2ShannonEntropy(s)
    let hasEquals = s.contains("=")
    
    var score = 0.0
    
    if n >= 40 { score += 1.5 }
    else if n >= 32 { score += 1.2 }
    else if n >= 24 { score += 0.8 }
    else if n >= 16 { score += 0.3 }
    
    if variety >= 0.75 { score += 1.0 }
    else if variety >= 0.50 { score += 0.5 }
    
    if entropy >= 4.5 { score += 2.0 }
    else if entropy >= 4.0 { score += 1.5 }
    else if entropy >= 3.5 { score += 1.0 }
    else if entropy >= 3.0 { score += 0.5 }
    else { score -= 0.5 }
    
    if digitRatio >= 0.15 && digitRatio <= 0.6 { score += 0.4 }
    if symbolRatio >= 0.05 && symbolRatio <= 0.3 { score += 0.5 }
    if upperRatio >= 0.2 && lowerRatio >= 0.2 { score += 0.4 }
    
    if hasEquals && n >= 24 { score += 0.3 }
    
    if lowerRatio > 0.7 && digitRatio < 0.1 && symbolRatio < 0.05 { score -= 2.0 }
    if v2LooksLikeFilename(s) { score -= 1.5 }
    if upperRatio == 1.0 || lowerRatio == 1.0 { score -= 0.8 }
    if symbolRatio == 0 && digitRatio == 0 { score -= 1.5 }
    if v2ContainsCommonPattern(s.lowercased()) { score -= 2.0 }
    
    let threshold: Double
    if n >= 32 { threshold = 2.0 }
    else if n >= 20 { threshold = 2.5 }
    else { threshold = 3.0 }
    
    return score >= threshold
}

// MARK: - Helpers

private let v2KeywordPrefixes: [String] = [
    "AKIA", "ASIA", "sk_live_", "sk_test_", "pk_live_", "pk_test_",
    "rk_live_", "rk_test_", "xoxb-", "xoxp-", "xoxa-", "xoxr-",
    "ghp_", "gho_", "ghu_", "ghs_", "ghr_", "github_pat_",
    "AIza", "ya29.", "glpat-", "gloas-", "glsa-",
]

private func v2HasKnownPrefix(_ s: String) -> Bool {
    for p in v2KeywordPrefixes {
        if s.hasPrefix(p) { return true }
    }
    return false
}

private func v2SafeStrip(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count > 2 {
        t = String(t.dropFirst().dropLast())
    } else if t.hasPrefix("'") && t.hasSuffix("'") && t.count > 2 {
        t = String(t.dropFirst().dropLast())
    }
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func v2LooksLikeJWT(_ s: String) -> Bool {
    let parts = s.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return false }
    for seg in parts {
        if seg.count < 8 { return false }
        for ch in seg.unicodeScalars {
            if !(v2IsAlphaNum(ch) || ch == "-" || ch == "_") { return false }
        }
    }
    return true
}

private func v2LooksLikeHex(_ s: String) -> Bool {
    guard s.count >= 24 else { return false }
    for ch in s.unicodeScalars {
        if !v2IsHex(ch) { return false }
    }
    return true
}

private func v2LooksLikeBase64(_ s: String) -> Bool {
    let n = s.count
    guard n >= 24 else { return false }
    guard n % 4 == 0 else { return false }
    for ch in s.unicodeScalars {
        if !v2IsBase64Char(ch) { return false }
    }
    return true
}

private func v2HasExcessiveRepetition(_ s: String) -> Bool {
    guard s.count >= 6 else { return false }
    var prevChar: Character?
    var repeatCount = 1
    var maxRepeat = 1
    for char in s {
        if char == prevChar {
            repeatCount += 1
            maxRepeat = max(maxRepeat, repeatCount)
        } else {
            repeatCount = 1
        }
        prevChar = char
    }
    return maxRepeat >= 4 || (Double(maxRepeat) / Double(s.count) > 0.3)
}

private func v2LooksLikeURL(_ s: String) -> Bool {
    if s.hasSuffix(".apps.googleusercontent.com") { return false }
    if s.hasSuffix(".firebaseapp.com") || s.contains(".amazoncognito.com") ||
       s.hasSuffix(".onmicrosoft.com") || s.hasSuffix(".azurewebsites.net") ||
       s.hasSuffix(".cloudapp.azure.com") || s.contains(".supabase.co") ||
       s.contains(".vercel.app") || s.contains(".netlify.app") ||
       s.contains(".herokuapp.com") || s.contains(".cloudflare.com") ||
       s.contains(".awsapps.com") || s.contains(".okta.com") ||
       s.contains(".auth0.com") { return false }
    return s.hasPrefix("http://") || s.hasPrefix("https://") || s.hasPrefix("www.") ||
           s.contains(".com/") || s.contains(".org/") || s.contains(".net/")
}

private func v2LooksLikeFilename(_ s: String) -> Bool {
    if let dotIndex = s.lastIndex(of: ".") {
        let afterDot = s[s.index(after: dotIndex)...]
        if afterDot.count >= 2 && afterDot.count <= 5 {
            return afterDot.allSatisfy { $0.isLetter }
        }
    }
    return false
}

private func v2ContainsCommonPattern(_ s: String) -> Bool {
    let commonPatterns = [
        "the", "and", "for", "are", "but", "not", "you", "all",
        "can", "her", "was", "one", "our", "out", "get", "has",
        "him", "his", "how", "man", "new", "now", "old", "see",
        "way", "who", "boy", "did", "its", "let", "put", "say",
        "she", "too", "use", "data", "user", "file", "name",
        "path", "temp", "admin", "config", "debug"
    ]
    for pattern in commonPatterns {
        if s.contains(pattern) { return true }
    }
    return false
}

private struct V2CharStats {
    var digits: Int = 0; var upper: Int = 0; var lower: Int = 0; var symbols: Int = 0
}

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
    let count = (hasLower ? 1 : 0) + (hasUpper ? 1 : 0) + (hasDigit ? 1 : 0) + (hasSymbol ? 1 : 0)
    return Double(count) / 4.0
}

private func v2ShannonEntropy(_ s: String) -> Double {
    if s.isEmpty { return 0.0 }
    var counts: [UInt32: Int] = [:]
    counts.reserveCapacity(min(64, s.count))
    var n = 0
    for ch in s.unicodeScalars {
        counts[ch.value, default: 0] += 1
        n += 1
    }
    let dn = Double(n)
    var ent = 0.0
    for (_, c) in counts {
        let p = Double(c) / dn
        ent -= p * log2(p)
    }
    return ent
}

private func v2IsDigit(_ ch: UnicodeScalar) -> Bool { ch.value >= 48 && ch.value <= 57 }
private func v2IsUpper(_ ch: UnicodeScalar) -> Bool { ch.value >= 65 && ch.value <= 90 }
private func v2IsLower(_ ch: UnicodeScalar) -> Bool { ch.value >= 97 && ch.value <= 122 }
private func v2IsAlphaNum(_ ch: UnicodeScalar) -> Bool { v2IsDigit(ch) || v2IsUpper(ch) || v2IsLower(ch) }
private func v2IsHex(_ ch: UnicodeScalar) -> Bool {
    switch ch.value {
    case 48...57: return true
    case 65...70: return true
    case 97...102: return true
    default: return false
    }
}
private func v2IsBase64Char(_ ch: UnicodeScalar) -> Bool {
    if v2IsAlphaNum(ch) { return true }
    return ch == "+" || ch == "/" || ch == "="
}