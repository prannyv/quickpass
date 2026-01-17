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
    @EnvironmentObject var clipboardManager: ClipboardManager
    @StateObject private var onePassword = OnePasswordCLI()
    
    @State private var showingAddCredential = false
    @State private var showingSettings = false
    @State private var showingQuickSave = false
    @State private var quickSaveTitle = ""
    @State private var isSavingQuick = false
    @State private var quickSaveError: String?
    @State private var showingSaveSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with connection status
                connectionStatusBar
                
                Divider()
                
                // Main content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Clipboard monitoring section
                        clipboardSection
                        
                        // 1Password section
                        onePasswordSection
                    }
                    .padding()
                }
            }
            .navigationTitle("QuickPass")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if onePassword.isSignedIn {
                        Button {
                            showingAddCredential = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Add API Credential")
                    }
                }
            }
            .sheet(isPresented: $showingAddCredential) {
                AddCredentialView(onePassword: onePassword, clipboardManager: clipboardManager)
            }
            .alert("Saved!", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("API credential saved to 1Password")
            }
        }
    }
    
    // MARK: - Quick Save Popover
    
    private var quickSavePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Save to 1Password")
                .font(.headline)
            
            TextField("Title", text: $quickSaveTitle)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            if !onePassword.availableVaults.isEmpty {
                HStack {
                    Text("Vault:")
                        .foregroundColor(.secondary)
                    Text(onePassword.availableVaults.first?.name ?? "Default")
                        .fontWeight(.medium)
                }
                .font(.caption)
            }
            
            // Preview of the key (truncated)
            if let key = clipboardManager.currentText {
                HStack {
                    Text("Key:")
                        .foregroundColor(.secondary)
                    Text(truncateKey(key))
                        .font(.system(.caption, design: .monospaced))
                }
                .font(.caption)
            }
            
            if let error = quickSaveError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack {
                Button("Cancel") {
                    showingQuickSave = false
                    quickSaveError = nil
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    performQuickSave()
                } label: {
                    if isSavingQuick {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(quickSaveTitle.isEmpty || isSavingQuick)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Helper Functions
    
    private func generateDefaultTitle() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy HH:mm"
        return "API Key - \(dateFormatter.string(from: Date()))"
    }
    
    private func truncateKey(_ key: String) -> String {
        if key.count <= 20 {
            return key
        }
        let prefix = key.prefix(8)
        let suffix = key.suffix(8)
        return "\(prefix)...\(suffix)"
    }
    
    private func performQuickSave() {
        guard let apiKey = clipboardManager.currentText, !apiKey.isEmpty else {
            quickSaveError = "No API key in clipboard"
            return
        }
        
        guard let vault = onePassword.availableVaults.first else {
            quickSaveError = "No vault available"
            return
        }
        
        isSavingQuick = true
        quickSaveError = nil
        
        Task {
            do {
                try await onePassword.createSimpleAPICredential(
                    title: quickSaveTitle,
                    apiKey: apiKey,
                    vault: vault.name
                )
                
                await MainActor.run {
                    isSavingQuick = false
                    showingQuickSave = false
                    showingSaveSuccess = true
                    quickSaveTitle = ""
                }
            } catch {
                await MainActor.run {
                    isSavingQuick = false
                    quickSaveError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Connection Status Bar
    
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(onePassword.isSignedIn ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(onePassword.isSignedIn ? "Connected to 1Password" : "Not connected")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let account = onePassword.currentAccount {
                Text(account.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Clipboard Section
    
    private var clipboardSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Clipboard Monitor", systemImage: "doc.on.clipboard")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Content:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(clipboardManager.currentText ?? "Empty")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                }
                
                HStack {
                    // API Key detection indicator
                    HStack(spacing: 6) {
                        Image(systemName: clipboardManager.isAPIKey ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(clipboardManager.isAPIKey ? .green : .secondary)
                        
                        Text(clipboardManager.isAPIKey ? "Looks like an API key" : "Not detected as API key")
                            .font(.caption)
                            .foregroundColor(clipboardManager.isAPIKey ? .primary : .secondary)
                    }
                    
                    Spacer()
                    
                    // Quick save button (only shown when API key detected and signed in)
                    if clipboardManager.isAPIKey && onePassword.isSignedIn {
                        HStack(spacing: 8) {
                            // Quick save with popover
                            Button {
                                quickSaveTitle = generateDefaultTitle()
                                showingQuickSave = true
                            } label: {
                                Label("Quick Save", systemImage: "bolt.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .popover(isPresented: $showingQuickSave) {
                                quickSavePopover
                            }
                            
                            // Full form button
                            Button {
                                showingAddCredential = true
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("More options...")
                        }
                    }
                }
            }
            .padding(4)
        }
    }
    
    // MARK: - 1Password Section
    
    private var onePasswordSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                Label("1Password", systemImage: "lock.shield")
                    .font(.headline)
                
                if onePassword.isLoading {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Connecting...")
                            .foregroundColor(.secondary)
                    }
                } else if onePassword.isSignedIn {
                    signedInView
                } else {
                    signedOutView
                }
                
                // Error display
                if let error = onePassword.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(4)
        }
    }
    
    private var signedOutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect to 1Password to automatically save your API keys")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                Task {
                    await onePassword.signIn()
                }
            } label: {
                Label("Connect to 1Password", systemImage: "person.badge.key")
            }
            .buttonStyle(.borderedProminent)
            
            // CLI availability check
            if !onePassword.checkCLIAvailable() {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.red)
                        Text("1Password CLI not found or not executable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let path = onePassword.getOPBinaryPath() {
                        Text("Found at: \(path) (but not executable)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Install via: brew install 1password-cli")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("1Password CLI found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let path = onePassword.getOPBinaryPath() {
                        Text(path)
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
            
            // Setup instructions
            DisclosureGroup("Setup Instructions") {
                VStack(alignment: .leading, spacing: 8) {
                    setupInstructionRow(number: 1, text: "Install 1Password desktop app")
                    setupInstructionRow(number: 2, text: "Open 1Password → Settings → Developer")
                    setupInstructionRow(number: 3, text: "Enable \"Integrate with 1Password CLI\"")
                    setupInstructionRow(number: 4, text: "Click \"Connect to 1Password\" above")
                }
                .padding(.top, 8)
            }
            .font(.caption)
        }
    }
    
    private func setupInstructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.medium)
                .frame(width: 20, alignment: .trailing)
            Text(text)
        }
        .foregroundColor(.secondary)
    }
    
    private var signedInView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Account info
            if let account = onePassword.currentAccount {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading) {
                        Text(account.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(account.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Disconnect") {
                        onePassword.signOut()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            // Vaults
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Available Vaults")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            try? await onePassword.refreshVaults()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                
                if onePassword.availableVaults.isEmpty {
                    Text("No vaults available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(onePassword.availableVaults) { vault in
                                VaultBadge(name: vault.name)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Vault Badge

struct VaultBadge: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .cornerRadius(6)
    }
}

// MARK: - Add Credential View

struct AddCredentialView: View {
    @ObservedObject var onePassword: OnePasswordCLI
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var credential = ""
    @State private var selectedVault: String = ""
    @State private var username = ""
    @State private var credentialType = ""
    @State private var hostname = ""
    @State private var notes = ""
    @State private var tags = ""
    
    @State private var isSaving = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                // Required fields
                Section("Required") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("API Key / Token")
                            Spacer()
                            if clipboardManager.isAPIKey {
                                Button("Paste from clipboard") {
                                    credential = clipboardManager.currentText ?? ""
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                        }
                        SecureField("Enter or paste your API key", text: $credential)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Picker("Vault", selection: $selectedVault) {
                        ForEach(onePassword.availableVaults) { vault in
                            Text(vault.name).tag(vault.name)
                        }
                    }
                }
                
                // Optional fields
                Section("Optional") {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Type (e.g., production, development)", text: $credentialType)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Hostname / URL", text: $hostname)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Tags (comma-separated)", text: $tags)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .font(.body)
                }
                
                // Error display
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add API Credential")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCredential()
                    }
                    .disabled(title.isEmpty || credential.isEmpty || selectedVault.isEmpty || isSaving)
                }
            }
            .onAppear {
                // Pre-fill with clipboard if it looks like an API key
                if clipboardManager.isAPIKey, let text = clipboardManager.currentText {
                    credential = text
                }
                // Select first vault by default
                if selectedVault.isEmpty, let firstVault = onePassword.availableVaults.first {
                    selectedVault = firstVault.name
                }
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
            }
            .alert("Credential Saved!", isPresented: $showingSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your API credential has been saved to 1Password.")
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func saveCredential() {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                let tagArray = tags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                let newCredential = OnePasswordCLI.NewAPICredential(
                    title: title,
                    vault: selectedVault,
                    credential: credential,
                    username: username.isEmpty ? nil : username,
                    type: credentialType.isEmpty ? nil : credentialType,
                    hostname: hostname.isEmpty ? nil : hostname,
                    notes: notes.isEmpty ? nil : notes,
                    tags: tagArray
                )
                
                try await onePassword.createAPICredential(newCredential)
                
                await MainActor.run {
                    isSaving = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardManager())
}
