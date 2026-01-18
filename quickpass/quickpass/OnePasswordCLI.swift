//
//  OnePasswordCLI.swift
//  quickpass
//
//  Created on 2026-01-17.
//

import Foundation
import Combine

/// Manages all interactions with the 1Password CLI (op)
/// Requires the `op` binary to be bundled in the app's Resources folder
@MainActor
final class OnePasswordCLI: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var currentAccount: Account?
    @Published private(set) var availableVaults: [Vault] = []
    @Published private(set) var lastError: OPError?
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Types
    
    enum OPError: LocalizedError {
        case binaryNotFound
        case binaryNotExecutable
        case desktopIntegrationDisabled
        case notSignedIn
        case commandFailed(String)
        case parseError(String)
        case vaultNotFound(String)
        case itemCreateFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "1Password CLI (op) not found in app bundle"
            case .binaryNotExecutable:
                return "1Password CLI binary is not executable"
            case .desktopIntegrationDisabled:
                return "Please enable 'Integrate with 1Password CLI' in 1Password app → Settings → Developer"
            case .notSignedIn:
                return "Not signed in to 1Password"
            case .commandFailed(let msg):
                return "Command failed: \(msg)"
            case .parseError(let msg):
                return "Failed to parse response: \(msg)"
            case .vaultNotFound(let name):
                return "Vault '\(name)' not found"
            case .itemCreateFailed(let msg):
                return "Failed to create item: \(msg)"
            }
        }
    }
    
    struct Account: Codable, Identifiable {
        let id: String
        let name: String
        let email: String
        let url: String
        let userUUID: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case email
            case url
            case userUUID = "user_uuid"
        }
    }
    
    struct Vault: Codable, Identifiable {
        let id: String
        let name: String
    }
    
    struct Item: Codable, Identifiable {
        let id: String
        let title: String
        let vault: VaultRef
        let category: String
        let createdAt: String?
        let updatedAt: String?
        
        struct VaultRef: Codable {
            let id: String
            let name: String?
        }
        
        enum CodingKeys: String, CodingKey {
            case id, title, vault, category
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
    
    /// Represents a field when creating a new API credential
    struct CredentialField {
        let label: String
        let value: String
        let type: FieldType
        let section: String?
        
        enum FieldType: String {
            case text = "text"
            case concealed = "concealed"
            case url = "url"
            case email = "email"
            case date = "date"
            case monthYear = "monthYear"
            case phone = "phone"
        }
        
        init(label: String, value: String, type: FieldType = .text, section: String? = nil) {
            self.label = label
            self.value = value
            self.type = type
            self.section = section
        }
        
        /// Formats the field as a CLI assignment string
        var cliAssignment: String {
            var assignment = ""
            if let section = section {
                assignment += "\(section)."
            }
            assignment += "\(label)[\(type.rawValue)]=\(value)"
            return assignment
        }
    }
    
    /// Configuration for creating a new API credential
    struct NewAPICredential {
        let title: String
        let vault: String
        let credential: String // The main API key/token
        let username: String?
        let type: String?       // e.g., "personal", "production", "development"
        let filename: String?   // For file-based credentials
        let validFrom: Date?
        let expiresAt: Date?
        let hostname: String?
        let notes: String?
        let tags: [String]
        let customFields: [CredentialField]
        
        init(
            title: String,
            vault: String,
            credential: String,
            username: String? = nil,
            type: String? = nil,
            filename: String? = nil,
            validFrom: Date? = nil,
            expiresAt: Date? = nil,
            hostname: String? = nil,
            notes: String? = nil,
            tags: [String] = [],
            customFields: [CredentialField] = []
        ) {
            self.title = title
            self.vault = vault
            self.credential = credential
            self.username = username
            self.type = type
            self.filename = filename
            self.validFrom = validFrom
            self.expiresAt = expiresAt
            self.hostname = hostname
            self.notes = notes
            self.tags = tags
            self.customFields = customFields
        }
    }
    
    // MARK: - Private Properties
    
    private let opBinaryURL: URL?
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    init() {
        self.opBinaryURL = Self.findOPBinary()
    }
    
    /// Searches for the op binary in multiple locations
    private static func findOPBinary() -> URL? {
        let fm = FileManager.default
        
        // List of paths to check, in priority order
        var searchPaths: [URL] = []
        
        // 1. App bundle Resources folder
        if let resourceURL = Bundle.main.resourceURL {
            searchPaths.append(resourceURL.appendingPathComponent("op"))
        }
        
        // 2. App bundle MacOS folder (auxiliary executables)
        if let execURL = Bundle.main.executableURL?.deletingLastPathComponent() {
            searchPaths.append(execURL.appendingPathComponent("op"))
        }
        
        // 3. Homebrew ARM path (most common on Apple Silicon)
        searchPaths.append(URL(fileURLWithPath: "/opt/homebrew/bin/op"))
        
        // 4. Homebrew Intel / standard path
        searchPaths.append(URL(fileURLWithPath: "/usr/local/bin/op"))
        
        // 5. Direct Caskroom path (in case symlink resolution fails)
        let caskroomPath = "/opt/homebrew/Caskroom/1password-cli"
        if let contents = try? fm.contentsOfDirectory(atPath: caskroomPath),
           let version = contents.first {
            searchPaths.append(URL(fileURLWithPath: "\(caskroomPath)/\(version)/op"))
        }
        
        // Search each path
        for path in searchPaths {
            // Resolve symlinks to get the actual file
            let resolvedPath = path.resolvingSymlinksInPath()
            
            // Check if file exists
            if fm.fileExists(atPath: resolvedPath.path) {
                // Verify it's executable by checking file attributes
                if let attributes = try? fm.attributesOfItem(atPath: resolvedPath.path),
                   let permissions = attributes[.posixPermissions] as? Int,
                   permissions & 0o111 != 0 { // Check if any execute bit is set
                    return resolvedPath
                }
                
                // Fallback: also try isExecutableFile (works for some cases)
                if fm.isExecutableFile(atPath: resolvedPath.path) {
                    return resolvedPath
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Public Methods
    
    /// Checks if the op CLI binary is available and ready to use
    func checkCLIAvailable() -> Bool {
        guard let url = opBinaryURL else { return false }
        let fm = FileManager.default
        
        // Check file exists
        guard fm.fileExists(atPath: url.path) else { return false }
        
        // Check executable permission via attributes
        if let attributes = try? fm.attributesOfItem(atPath: url.path),
           let permissions = attributes[.posixPermissions] as? Int,
           permissions & 0o111 != 0 {
            return true
        }
        
        // Fallback check
        return fm.isExecutableFile(atPath: url.path)
    }
    
    /// Gets the path to the op binary (for debugging)
    func getOPBinaryPath() -> String? {
        return opBinaryURL?.path
    }
    
    /// Debug helper: returns info about CLI detection
    func getCLIDebugInfo() -> String {
        guard let url = opBinaryURL else {
            return "op binary not found in any search path"
        }
        
        let fm = FileManager.default
        var info = "Path: \(url.path)\n"
        info += "Exists: \(fm.fileExists(atPath: url.path))\n"
        
        if let attributes = try? fm.attributesOfItem(atPath: url.path) {
            if let permissions = attributes[.posixPermissions] as? Int {
                info += "Permissions: \(String(permissions, radix: 8))\n"
                info += "Executable: \(permissions & 0o111 != 0)\n"
            }
            if let fileType = attributes[.type] as? FileAttributeType {
                info += "Type: \(fileType == .typeSymbolicLink ? "symlink" : "regular")\n"
            }
        }
        
        return info
    }
    
    /// Checks if desktop app integration is enabled and user can authenticate
    /// This will trigger a biometric/password prompt from the 1Password app
    func signIn() async {
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        do {
            // With desktop app integration, accounts won't show in `account list`
            // Instead, try to list vaults directly - this triggers the auth prompt
            let vaults = try await listVaults()
            
            if !vaults.isEmpty {
                availableVaults = vaults
                isSignedIn = true
                
                // Try to get detailed account info using `op account get`
                try? await getUserInfo()
                
                // Fallback: If getUserInfo didn't set account, try listAccounts
                if currentAccount == nil {
                    if let accounts = try? await listAccounts(), let first = accounts.first {
                        currentAccount = first
                    } else {
                        // Create a placeholder account for desktop app integration
                        currentAccount = Account(
                            id: "desktop-integration",
                            name: "Pranav",
                            email: "Connected via Desktop App",
                            url: "1password.com",
                            userUUID: nil
                        )
                    }
                }
            } else {
                lastError = .notSignedIn
                isSignedIn = false
            }
        } catch let error as OPError {
            lastError = error
            isSignedIn = false
        } catch {
            lastError = .commandFailed(error.localizedDescription)
            isSignedIn = false
        }
    }
    
    /// Signs out and clears local state
    func signOut() {
        isSignedIn = false
        currentAccount = nil
        availableVaults = []
        lastError = nil
    }
    
    /// Refreshes the list of available vaults
    func refreshVaults() async throws {
        availableVaults = try await listVaults()
    }
    
    /// Lists all accounts configured in 1Password
    func listAccounts() async throws -> [Account] {
        let result = try await runOP(arguments: ["account", "list", "--format", "json"])
        
        guard let data = result.stdout.data(using: .utf8) else {
            throw OPError.parseError("Invalid response data")
        }
        
        do {
            return try decoder.decode([Account].self, from: data)
        } catch {
            // If no accounts, op returns empty or error
            if result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return []
            }
            throw OPError.parseError(error.localizedDescription)
        }
    }
    
    /// Gets the current account details using `op whoami`
    private struct OnePasswordWhoami: Codable {
        let email: String
        
        enum CodingKeys: String, CodingKey {
            case email
        }
    }
    
    /// Fetches detailed account information using `op whoami`
    func getUserInfo() async throws {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/op")
        process.arguments = ["whoami", "--format=json"]
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let whoami = try decoder.decode(OnePasswordWhoami.self, from: data)
        
        // Extract name from email (part before @)
        let name = whoami.email.components(separatedBy: "@").first ?? whoami.email
        
        // Update currentAccount with the fetched details
        if currentAccount != nil {
            currentAccount = Account(
                id: currentAccount!.id,
                name: name,
                email: whoami.email,
                url: currentAccount!.url,
                userUUID: currentAccount!.userUUID
            )
        } else {
            // Create new account if one doesn't exist
            currentAccount = Account(
                id: "account-\(UUID().uuidString)",
                name: name,
                email: whoami.email,
                url: "1password.com",
                userUUID: nil
            )
        }
    }
    
    /// Lists all vaults accessible to the current user
    func listVaults() async throws -> [Vault] {
        let result = try await runOP(arguments: ["vault", "list", "--format", "json"])
        
        guard let data = result.stdout.data(using: .utf8) else {
            throw OPError.parseError("Invalid response data")
        }
        
        return try decoder.decode([Vault].self, from: data)
    }
    
    /// Creates a new API credential in the specified vault
    /// - Parameter credential: The credential configuration
    /// - Returns: The created item
    @discardableResult
    func createAPICredential(_ credential: NewAPICredential) async throws -> Item {
        var arguments = [
            "item", "create",
            "--category", "API Credential",
            "--title", credential.title,
            "--vault", credential.vault,
            "--format", "json"
        ]
        
        // Add the main credential field
        arguments.append("credential=\(credential.credential)")
        
        // Add optional built-in fields
        if let username = credential.username, !username.isEmpty {
            arguments.append("username=\(username)")
        }
        
        if let type = credential.type, !type.isEmpty {
            arguments.append("type=\(type)")
        }
        
        if let filename = credential.filename, !filename.isEmpty {
            arguments.append("filename=\(filename)")
        }
        
        if let hostname = credential.hostname, !hostname.isEmpty {
            arguments.append("hostname=\(hostname)")
        }
        
        // Add dates if provided
        if let validFrom = credential.validFrom {
            let formatter = ISO8601DateFormatter()
            arguments.append("valid from=\(formatter.string(from: validFrom))")
        }
        
        if let expiresAt = credential.expiresAt {
            let formatter = ISO8601DateFormatter()
            arguments.append("expires=\(formatter.string(from: expiresAt))")
        }
        
        // Add notes
        if let notes = credential.notes, !notes.isEmpty {
            arguments.append("notesPlain=\(notes)")
        }
        
        // Add tags
        if !credential.tags.isEmpty {
            arguments.append("--tags")
            arguments.append(credential.tags.joined(separator: ","))
        }
        
        // Add custom fields
        for field in credential.customFields {
            arguments.append(field.cliAssignment)
        }
        
        let result = try await runOP(arguments: arguments)
        
        guard let data = result.stdout.data(using: .utf8) else {
            throw OPError.parseError("Invalid response data")
        }
        
        do {
            return try decoder.decode(Item.self, from: data)
        } catch {
            throw OPError.itemCreateFailed(result.stderr.isEmpty ? error.localizedDescription : result.stderr)
        }
    }
    
    /// Creates a simple API credential with just title, vault, and the key
    /// - Parameters:
    ///   - title: Name of the credential
    ///   - apiKey: The API key/token value
    ///   - vault: Vault to store in (defaults to first available vault)
    /// - Returns: The created item
    @discardableResult
    func createSimpleAPICredential(title: String, apiKey: String, vault: String? = nil) async throws -> Item {
        let targetVault = vault ?? availableVaults.first?.name ?? "Private"
        
        let credential = NewAPICredential(
            title: title,
            vault: targetVault,
            credential: apiKey
        )
        
        return try await createAPICredential(credential)
    }
    
    /// Lists items in a specific vault
    func listItems(in vault: String? = nil) async throws -> [Item] {
        var arguments = ["item", "list", "--format", "json"]
        
        if let vault = vault {
            arguments.append("--vault")
            arguments.append(vault)
        }
        
        let result = try await runOP(arguments: arguments)
        
        guard let data = result.stdout.data(using: .utf8) else {
            throw OPError.parseError("Invalid response data")
        }
        
        return try decoder.decode([Item].self, from: data)
    }
    
    /// Gets details of a specific item
    func getItem(id: String, vault: String? = nil) async throws -> Item {
        var arguments = ["item", "get", id, "--format", "json"]
        
        if let vault = vault {
            arguments.append("--vault")
            arguments.append(vault)
        }
        
        let result = try await runOP(arguments: arguments)
        
        guard let data = result.stdout.data(using: .utf8) else {
            throw OPError.parseError("Invalid response data")
        }
        
        return try decoder.decode(Item.self, from: data)
    }
    
    /// Deletes an item
    func deleteItem(id: String, vault: String? = nil) async throws {
        var arguments = ["item", "delete", id]
        
        if let vault = vault {
            arguments.append("--vault")
            arguments.append(vault)
        }
        
        _ = try await runOP(arguments: arguments)
    }
    
    /// Checks the version of the op CLI
    func getVersion() async throws -> String {
        let result = try await runOP(arguments: ["--version"])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Private Methods
    
    private struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }
    
    private func runOP(arguments: [String]) async throws -> ProcessResult {
        guard let opURL = opBinaryURL else {
            throw OPError.binaryNotFound
        }
        
        guard FileManager.default.isExecutableFile(atPath: opURL.path) else {
            throw OPError.binaryNotExecutable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = opURL
                process.arguments = arguments
                
                // Set up environment for desktop app integration
                var environment = ProcessInfo.processInfo.environment
                environment["OP_BIOMETRIC_UNLOCK_ENABLED"] = "true"
                process.environment = environment
                
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    
                    let result = ProcessResult(
                        exitCode: process.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    )
                    
                    // Check for common errors
                    if process.terminationStatus != 0 {
                        let errorText = stderr.lowercased()
                        
                        if errorText.contains("not currently signed in") || errorText.contains("session expired") {
                            continuation.resume(throwing: OPError.notSignedIn)
                            return
                        }
                        if errorText.contains("connecting to desktop app") || errorText.contains("not connected") {
                            continuation.resume(throwing: OPError.desktopIntegrationDisabled)
                            return
                        }
                        if errorText.contains("no accounts configured") || errorText.contains("turn on the 1password desktop app integration") {
                            continuation.resume(throwing: OPError.desktopIntegrationDisabled)
                            return
                        }
                        if errorText.contains("authorization denied") || errorText.contains("user denied") {
                            continuation.resume(throwing: OPError.notSignedIn)
                            return
                        }
                        continuation.resume(throwing: OPError.commandFailed(stderr.isEmpty ? "Exit code: \(process.terminationStatus)" : stderr))
                        return
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: OPError.commandFailed(error.localizedDescription))
                }
            }
        }
    }
}

