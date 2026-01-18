//
//  ContentView.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - MAIN CONTENT VIEW

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    // EDITED: Use EnvironmentObject to share the session and fix double-login
    @EnvironmentObject var onePassword: OnePasswordCLI
    
    @State private var showingAddCredential = false
    @State private var showingSettings = false
    @State private var showingQuickSave = false
    @State private var quickSaveTitle = ""
    @State private var isSavingQuick = false
    @State private var quickSaveError: String?
    @State private var showingSaveSuccess = false
    
    //Tracking logic
    @State private var vulnerabilitiesStopped: Int = 0

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
                        
                        Divider()
                        
                        // --- POPUP TRIGGER BUTTON ---
                        Button(action: {
                            // Pass clipboard manager and onePassword to the popup
                            OnePasswordWindowManager.shared.showPopup(
                                clipboardManager: clipboardManager,
                                onePassword: onePassword
                            )
                        }) {
                            HStack {
                                Image(systemName: "lock.square.stack.fill")
                                Text("Trigger 1Password Popup")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.bordered)
                        .tint(.indigo)
                    }
                    .padding()
                }
                
                // NEW: Sticky Footer for Clear action (stays at bottom)
                if onePassword.isSignedIn {
                    Divider()
                    HStack {
                        Spacer()
                        Button("Clear Clipboard") {
                            NSPasteboard.general.clearContents()
                            clipboardManager.refresh()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
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
            
            // Logic: Increment counter whenever a new API key is detected
            .onChange(of: clipboardManager.isAPIKey) { newValue in
                if newValue {
                    vulnerabilitiesStopped += 1
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
    
    // MARK: - Quick Save Popover (Internal)
    
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
                // Account info section (KEEP THIS - has your primary Disconnect button)
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
                        
                        // THIS IS YOUR PRIMARY DISCONNECT BUTTON
                        Button("Disconnect") {
                            onePassword.signOut()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                // Vulnerability Counter
                HStack {
                    Spacer()
                    Text("🛡️ We have stopped \(vulnerabilitiesStopped) vulnerabilities")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Vaults List (EDTED: Redundant footer buttons removed)
                VStack(alignment: .leading, spacing: 8) {
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

// MARK: - HELPER VIEWS

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

// MARK: - POPUP WINDOW MANAGER & VIEWS (MERGED)

struct OnePasswordPopupView: View {
    // Callbacks to control the window
    var onClose: () -> Void
    var onExpand: (NSSize) -> Void // Tells the window to resize
    
    // Injected dependencies
    @ObservedObject var clipboardManager: ClipboardManager
    @ObservedObject var onePassword: OnePasswordCLI
    
    // State for the transition
    @State private var isExpanded = false
    
    // Form Fields
    @State private var itemName: String = "API Credential"
    @State private var tags: [String] = []
    @State private var tagInput: String = ""
    @State private var website: String = ""
    @State private var selectedVault: String = ""
    
    // Save state
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSuccess = false
    
    // Computed property for token display (first 5 chars + "...")
    private var tokenDisplay: String {
        guard let text = clipboardManager.currentText, !text.isEmpty else {
            return "No clipboard content"
        }
        if text.count <= 5 {
            return text
        }
        return String(text.prefix(5)) + "..."
    }
    
    // Constants for Window Sizes
    let collapsedSize = NSSize(width: 340, height: 160)
    let expandedSize = NSSize(width: 340, height: 450)
    
    // MARK: - Save to 1Password
    
    private func saveToOnePassword() {
        guard let token = clipboardManager.currentText, !token.isEmpty else {
            saveError = "No token in clipboard"
            return
        }
        
        guard !itemName.isEmpty else {
            saveError = "Please enter a name"
            return
        }
        
        guard !selectedVault.isEmpty else {
            saveError = "Please select a vault"
            return
        }
        
        isSaving = true
        saveError = nil
        showSuccess = false
        
        Task {
            do {
                let credential = OnePasswordCLI.NewAPICredential(
                    title: itemName,
                    vault: selectedVault,
                    credential: token,
                    hostname: website.isEmpty ? nil : website,
                    tags: tags
                )
                
                _ = try await onePassword.createAPICredential(credential)
                
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                    
                    // Auto-close after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onClose()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- HEADER ---
            HStack {
                Image(systemName: "lock.fill") // Placeholder for 1Password Logo
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.blue))
                    .font(.caption)
                
                Text("Save in 1Password?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .horizontal], 16)
            
            if !isExpanded {
                // --- COLLAPSED STATE (Screenshot Match) ---
                VStack(alignment: .leading, spacing: 20) {
                    Text(itemName)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.top, 10)
                        .padding(.leading, 4)
                    
                    HStack(spacing: 12) {
                        Button("Dismiss") {
                            onClose()
                        }
                        .buttonStyle(DarkButtonStyle())
                        
                        Button("Save item") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded = true
                            }
                            // Trigger window resize
                            onExpand(expandedSize)
                        }
                        .buttonStyle(BlueButtonStyle())
                    }
                }
                .padding(16)
                .transition(.opacity)
                
            } else {
                // --- EXPANDED STATE (Form) ---
                VStack(alignment: .leading, spacing: 15) {
                    
                    // Fields
                    DarkTextField(label: "Name", text: $itemName)
                    
                    // Token field - disabled, shows first 5 chars + "..."
                    DarkDisabledField(label: "Token", text: tokenDisplay)
                    
                    DarkTagInput(
                        label: "Tags",
                        tags: $tags,
                        tagInput: $tagInput
                    )
                    
                    // Vault dropdown
                    DarkVaultPicker(
                        label: "Vault",
                        selection: $selectedVault,
                        vaults: onePassword.availableVaults
                    )
                    
                    DarkTextField(label: "Website", text: $website)
                    
                    Spacer()
                    
                    // Error display
                    if let error = saveError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                    }
                    
                    // Success display
                    if showSuccess {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Saved to 1Password!")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                    }
                    
                    // Footer Actions
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            onClose()
                        }
                        .buttonStyle(DarkButtonStyle())
                        .disabled(isSaving)
                        
                        Button {
                            saveToOnePassword()
                        } label: {
                            if isSaving {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .colorScheme(.dark)
                                    Text("Saving...")
                                }
                            } else {
                                Text("Save")
                            }
                        }
                        .buttonStyle(BlueButtonStyle())
                        .disabled(isSaving || itemName.isEmpty || selectedVault.isEmpty || clipboardManager.currentText == nil)
                    }
                }
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: isExpanded ? expandedSize.width : collapsedSize.width,
               height: isExpanded ? expandedSize.height : collapsedSize.height,
               alignment: .top)
        .background(Color(red: 0.15, green: 0.15, blue: 0.16)) // Dark grey background
        .cornerRadius(12)
        // Add a thin border to match macOS dark windows
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            // Default to first vault if available
            if selectedVault.isEmpty, let firstVault = onePassword.availableVaults.first {
                selectedVault = firstVault.name
            }
        }
    }
}

// --- STYLING HELPERS ---

struct DarkTextField: View {
    var label: String
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .foregroundColor(.white)
        }
    }
}

struct DarkDisabledField: View {
    var label: String
    var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
                .foregroundColor(.gray)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct DarkVaultPicker: View {
    var label: String
    @Binding var selection: String
    var vaults: [OnePasswordCLI.Vault]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            Menu {
                ForEach(vaults) { vault in
                    Button(vault.name) {
                        selection = vault.name
                    }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select a vault..." : selection)
                        .foregroundColor(selection.isEmpty ? .gray : .white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
        }
    }
}

struct DarkTagInput: View {
    var label: String
    @Binding var tags: [String]
    @Binding var tagInput: String
    
    @State private var isAddingTag = false
    private let maxTags = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            
            FlowLayout(spacing: 8) {
                // Display existing tags as pills
                ForEach(tags, id: \.self) { tag in
                    TagPill(text: tag) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
                
                // Add tag button or inline input (only if under limit)
                if tags.count < maxTags {
                    if isAddingTag {
                        // Inline input field
                        HStack(spacing: 4) {
                            TextField("", text: $tagInput)
                                .textFieldStyle(.plain)
                                .frame(width: 80)
                                .foregroundColor(.white)
                                .onSubmit {
                                    addTag()
                                }
                                .onExitCommand {
                                    isAddingTag = false
                                    tagInput = ""
                                }
                            
                            Button {
                                addTag()
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                isAddingTag = false
                                tagInput = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    } else {
                        // Add tag button
                        Button {
                            isAddingTag = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Add tag")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Avoid duplicates and respect max limit
        if !tags.contains(trimmed) && tags.count < maxTags {
            withAnimation(.easeInOut(duration: 0.15)) {
                tags.append(trimmed)
            }
        }
        tagInput = ""
        isAddingTag = false
    }
}

struct TagPill: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.blue.opacity(0.6))
        .cornerRadius(12)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        totalHeight = currentY + lineHeight
        
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

struct BlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct DarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// --- WINDOW MANAGER CLASS ---

class OnePasswordWindowManager {
    static let shared = OnePasswordWindowManager()
    private var popupPanel: NSPanel?
    
    func showPopup(clipboardManager: ClipboardManager, onePassword: OnePasswordCLI) {
        if popupPanel != nil {
            popupPanel?.makeKeyAndOrderFront(nil)
            return
        }
        
        let initialSize = NSSize(width: 340, height: 160)
        
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView], // Borderless look
            backing: .buffered,
            defer: false
        )
        
        // Window Configuration for "Popup" look
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear // Let SwiftUI handle background
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        
        // Inject View with Actions and Dependencies
        let contentView = OnePasswordPopupView(
            onClose: { [weak self] in
                self?.closeWindow()
            },
            onExpand: { [weak panel] newSize in
                // Animate the window frame change
                guard let panel = panel else { return }
                var frame = panel.frame
                let diff = newSize.height - frame.height
                frame.origin.y -= diff // Grow downwards (move origin down)
                frame.size = newSize
                panel.animator().setFrame(frame, display: true)
            },
            clipboardManager: clipboardManager,
            onePassword: onePassword
        )
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        
        self.popupPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        popupPanel?.close()
        popupPanel = nil
    }
}

#Preview {
    // Updated preview with a constant binding
    ContentView()
        .environmentObject(ClipboardManager())
}