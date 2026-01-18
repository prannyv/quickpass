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
        return v2CheckIsAPIKey(text)
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


// bryant model/algo CALL "v2CheckIsAPIKey" - IMPROVED VERSION
import Foundation

// MARK: - Public API

/// Fast, heuristic "API key likeness" check.
/// Designed for ~instant evaluation on 10–128 char strings.
///
/// - Returns: true if the token looks like an API key / secret / token.
public func v2CheckIsAPIKey(_ raw: String) -> Bool {
    let s = v2SafeStrip(raw)
    let n = s.count
    
    // Basic bounds
    if n < 10 { return false }
    if n > 256 { return false } // Changed: very long is likely text, not secret
    
    // Stage 0: Quick rejects (fast path to avoid false positives)
    if v2QuickReject(s, length: n) {
        return false
    }
    
    // Stage 1: Hard signals - known prefixes and strong shapes
    if let hardResult = v2CheckHardSignals(s, length: n) {
        return hardResult
    }
    
    // Stage 2: Soft scoring with improved penalties
    return v2SoftScore(s, length: n)
}

// MARK: - Stage 0: Quick Rejects (NEW)

private func v2QuickReject(_ s: String, length n: Int) -> Bool {
    let lower = s.lowercased()
    
    // Known false positive patterns
    let falsePositives = [
        "example", "test", "sample", "placeholder", "your_key_here",
        "password", "secret", "token", "apikey", "api_key",
        "lorem", "ipsum", "dummy", "mock", "fake",
        "xxxxxxxxxx", "123456789", "undefined", "null"
    ]
    
    for pattern in falsePositives {
        if lower.contains(pattern) { return true }
    }
    
    // Has spaces (very unlikely for real secrets)
    if s.contains(" ") && n > 15 {
        return true
    }
    
    // Excessive character repetition (e.g., "aaaaaaaaa")
    if v2HasExcessiveRepetition(s) {
        return true
    }
    
    // URL/domain pattern
    if v2LooksLikeURL(lower) {
        return true
    }
    
    // Email pattern
    if lower.contains("@") && lower.contains(".") {
        return true
    }
    
    // Path-like pattern (multiple slashes)
    if s.filter({ $0 == "/" }).count >= 2 {
        return true
    }
    
    return false
}

// MARK: - Stage 1: Hard Signals (IMPROVED)

private func v2CheckHardSignals(_ s: String, length n: Int) -> Bool? {
    // Known vendor prefixes with stricter length requirements
    if v2HasKnownPrefix(s) {
        // Most vendor keys have minimum lengths
        let minLengths: [String: Int] = [
            "AKIA": 20,         // AWS access key
            "ASIA": 20,         // AWS temp
            "sk_live_": 32,     // Stripe live
            "sk_test_": 32,     // Stripe test
            "pk_live_": 32,     // Stripe public live
            "pk_test_": 32,     // Stripe public test
            "xoxb-": 50,        // Slack bot
            "xoxp-": 50,        // Slack user
            "ghp_": 40,         // GitHub PAT
            "gho_": 40,         // GitHub OAuth
            "ghu_": 40,         // GitHub user
            "ghs_": 40,         // GitHub server
            "github_pat_": 82,  // GitHub fine-grained PAT
            "AIza": 39,         // Google API (usually 39)
        ]
        
        for (prefix, minLen) in minLengths {
            if s.hasPrefix(prefix) && n >= minLen {
                return true
            }
        }
        
        // Generic known prefix match (fallback)
        if n >= 16 {
            return true
        }
    }
    
    // JWT - more strict
    if v2LooksLikeJWT(s) && n >= 100 { // JWTs are typically 100+ chars
        return true
    }
    
    // Hex - tighter range
    if v2LooksLikeHex(s) && n >= 32 && n <= 128 {
        return true
    }
    
    // Base64 - with additional validation
    if v2LooksLikeBase64(s) && n >= 32 && n % 4 == 0 {
        // Must have mix of chars (not just letters)
        let hasDigits = s.contains(where: { $0.isNumber })
        let hasSymbols = s.contains("+") || s.contains("/") || s.contains("=")
        if hasDigits || hasSymbols {
            return true
        }
    }
    
    // Known secret/credential domain patterns (these ARE credentials)
    let secretDomains = [
        ".apps.googleusercontent.com",  // Google OAuth Client IDs
        ".firebaseapp.com",             // Firebase
        ".amazoncognito.com",           // AWS Cognito
        ".onmicrosoft.com",             // Microsoft/Azure
        ".azurewebsites.net",           // Azure
        ".cloudapp.azure.com",          // Azure
        ".supabase.co",                 // Supabase
        ".vercel.app",                  // Vercel
        ".netlify.app",                 // Netlify
        ".herokuapp.com",               // Heroku
        ".awsapps.com",                 // AWS
        ".okta.com",                    // Okta
        ".auth0.com"                    // Auth0
    ]
    
    let lower = s.lowercased()
    for domain in secretDomains {
        if lower.hasSuffix(domain) || lower.contains(domain) {
            // These domain patterns indicate credentials/secrets
            return true
        }
    }
    
    return nil // Continue to soft scoring
}

// MARK: - Stage 2: Soft Scoring (IMPROVED)

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
    
    // Length bonuses (adjusted)
    if n >= 40 { score += 1.5 }
    else if n >= 32 { score += 1.2 }
    else if n >= 24 { score += 0.8 }
    else if n >= 16 { score += 0.3 }
    
    // Character variety
    if variety >= 0.75 { score += 1.0 }
    else if variety >= 0.50 { score += 0.5 }
    
    // Entropy is critical (increased weight)
    if entropy >= 4.5 { score += 2.0 }       // Very high randomness
    else if entropy >= 4.0 { score += 1.5 }
    else if entropy >= 3.5 { score += 1.0 }
    else if entropy >= 3.0 { score += 0.5 }
    else { score -= 0.5 }                    // Low entropy penalty
    
    // Character distribution bonuses
    if digitRatio >= 0.15 && digitRatio <= 0.6 { score += 0.4 }
    if symbolRatio >= 0.05 && symbolRatio <= 0.3 { score += 0.5 }
    if upperRatio >= 0.2 && lowerRatio >= 0.2 { score += 0.4 } // Mixed case
    
    // Base64 padding hint
    if hasEquals && n >= 24 { score += 0.3 }
    
    // STRONGER PENALTIES
    
    // Too much lowercase, few digits (normal text)
    if lowerRatio > 0.7 && digitRatio < 0.1 && symbolRatio < 0.05 {
        score -= 2.0  // Increased from -1.0
    }
    
    // Filename pattern (extension-like)
    if v2LooksLikeFilename(s) {
        score -= 1.5  // Increased from -0.5
    }
    
    // All same case (less common in secrets)
    if upperRatio == 1.0 || lowerRatio == 1.0 {
        score -= 0.8
    }
    
    // No symbols or digits (very suspicious)
    if symbolRatio == 0 && digitRatio == 0 {
        score -= 1.5
    }
    
    // Contains common word patterns
    if v2ContainsCommonPattern(s.lowercased()) {
        score -= 2.0  // NEW: Strong penalty
    }
    
    // Dynamic threshold based on length
    let threshold: Double
    if n >= 32 {
        threshold = 2.0      // Longer strings, lower threshold
    } else if n >= 20 {
        threshold = 2.5
    } else {
        threshold = 3.0      // Shorter strings, higher threshold
    }
    
    return score >= threshold
}

// MARK: - Known prefixes (EXPANDED)

private let v2KeywordPrefixes: [String] = [
    "AKIA",         // AWS access key id
    "ASIA",         // AWS temp
    "sk_live_",     // Stripe live secret
    "sk_test_",     // Stripe test secret
    "pk_live_",     // Stripe live public
    "pk_test_",     // Stripe test public
    "rk_live_",     // Stripe restricted live
    "rk_test_",     // Stripe restricted test
    "xoxb-",        // Slack bot
    "xoxp-",        // Slack user
    "xoxa-",        // Slack app-level
    "xoxr-",        // Slack refresh
    "ghp_",         // GitHub personal access token
    "gho_",         // GitHub OAuth token
    "ghu_",         // GitHub user-to-server token
    "ghs_",         // GitHub server-to-server token
    "ghr_",         // GitHub refresh token
    "github_pat_",  // GitHub fine-grained PAT
    "AIza",         // Google API key
    "ya29.",        // Google OAuth 2.0 access token
    "glpat-",       // GitLab personal access token
    "gloas-",       // GitLab OAuth application secret
    "glsa-",        // GitLab system access token
]

private func v2HasKnownPrefix(_ s: String) -> Bool {
    for p in v2KeywordPrefixes {
        if s.hasPrefix(p) { return true }
    }
    return false
}

// MARK: - String cleanup

private func v2SafeStrip(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Remove surrounding quotes (one layer)
    if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count > 2 {
        t = String(t.dropFirst().dropLast())
    } else if t.hasPrefix("'") && t.hasSuffix("'") && t.count > 2 {
        t = String(t.dropFirst().dropLast())
    }
    
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
            if !(v2IsAlphaNum(ch) || ch == "-" || ch == "_") {
                return false
            }
        }
    }
    return true
}

/// Hex secret: >= 24 chars, all hex
private func v2LooksLikeHex(_ s: String) -> Bool {
    guard s.count >= 24 else { return false }
    for ch in s.unicodeScalars {
        if !v2IsHex(ch) { return false }
    }
    return true
}

/// Base64: >= 24 chars, only base64 chars, length multiple of 4
private func v2LooksLikeBase64(_ s: String) -> Bool {
    let n = s.count
    guard n >= 24 else { return false }
    guard n % 4 == 0 else { return false }
    
    for ch in s.unicodeScalars {
        if !v2IsBase64Char(ch) { return false }
    }
    return true
}

// MARK: - NEW Helper Functions

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
    
    // If any character repeats 4+ times consecutively, or
    // if max repeat is >30% of string length
    return maxRepeat >= 4 || (Double(maxRepeat) / Double(s.count) > 0.3)
}

private func v2LooksLikeURL(_ s: String) -> Bool {
    // Don't flag Google OAuth Client IDs as URLs
    if s.hasSuffix(".apps.googleusercontent.com") {
        return false
    }
    
    // Don't flag other known secret/API key domains
    if s.hasSuffix(".firebaseapp.com") ||
       s.contains(".amazoncognito.com") ||
       s.hasSuffix(".onmicrosoft.com") ||
       s.hasSuffix(".azurewebsites.net") ||
       s.hasSuffix(".cloudapp.azure.com") ||
       s.contains(".supabase.co") ||
       s.contains(".vercel.app") ||
       s.contains(".netlify.app") ||
       s.contains(".herokuapp.com") ||
       s.contains(".cloudflare.com") ||
       s.contains(".awsapps.com") ||
       s.contains(".okta.com") ||
       s.contains(".auth0.com") {
        return false
    }
    
    // Now check for actual URLs
    return s.hasPrefix("http://") ||
           s.hasPrefix("https://") ||
           s.hasPrefix("www.") ||
           s.contains(".com/") ||  // Note the trailing slash
           s.contains(".org/") ||
           s.contains(".net/")
}

private func v2LooksLikeFilename(_ s: String) -> Bool {
    // Check for file extension pattern
    if let dotIndex = s.lastIndex(of: ".") {
        let afterDot = s[s.index(after: dotIndex)...]
        // Extension should be 2-5 chars
        if afterDot.count >= 2 && afterDot.count <= 5 {
            // And should only contain letters
            return afterDot.allSatisfy { $0.isLetter }
        }
    }
    return false
}

private func v2ContainsCommonPattern(_ s: String) -> Bool {
    // Common words that appear in non-secret strings
    let commonPatterns = [
        "the", "and", "for", "are", "but", "not", "you", "all",
        "can", "her", "was", "one", "our", "out", "get", "has",
        "him", "his", "how", "man", "new", "now", "old", "see",
        "way", "who", "boy", "did", "its", "let", "put", "say",
        "she", "too", "use", "data", "user", "file", "name",
        "path", "temp", "admin", "config", "debug"
    ]
    
    for pattern in commonPatterns {
        if s.contains(pattern) {
            return true
        }
    }
    
    return false
}

// MARK: - Character stats

private struct V2CharStats {
    var digits: Int = 0
    var upper: Int = 0
    var lower: Int = 0
    var symbols: Int = 0
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
    let count =
        (hasLower ? 1 : 0) +
        (hasUpper ? 1 : 0) +
        (hasDigit ? 1 : 0) +
        (hasSymbol ? 1 : 0)
    return Double(count) / 4.0
}

/// Shannon entropy in bits/character
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

// MARK: - Character classification

private func v2IsDigit(_ ch: UnicodeScalar) -> Bool {
    ch.value >= 48 && ch.value <= 57  // 0-9
}

private func v2IsUpper(_ ch: UnicodeScalar) -> Bool {
    ch.value >= 65 && ch.value <= 90  // A-Z
}

private func v2IsLower(_ ch: UnicodeScalar) -> Bool {
    ch.value >= 97 && ch.value <= 122  // a-z
}

private func v2IsAlphaNum(_ ch: UnicodeScalar) -> Bool {
    v2IsDigit(ch) || v2IsUpper(ch) || v2IsLower(ch)
}

private func v2IsHex(_ ch: UnicodeScalar) -> Bool {
    switch ch.value {
    case 48...57:  return true  // 0-9
    case 65...70:  return true  // A-F
    case 97...102: return true  // a-f
    default: return false
    }
}

private func v2IsBase64Char(_ ch: UnicodeScalar) -> Bool {
    if v2IsAlphaNum(ch) { return true }
    return ch == "+" || ch == "/" || ch == "="
}