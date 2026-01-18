//
//  ContentView.swift
//  quickpass
//
//  Created by Eileen Zhao on 2026-01-17.
//

import SwiftUI
import AppKit

// MARK: - MAIN CONTENT VIEW

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var onePassword: OnePasswordCLI
    
    @State private var showingAddCredential = false
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
                        // Greeting
                        if let account = onePassword.currentAccount {
                            Text("Hello \(account.name)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                        
                        // Clipboard monitoring section
                        clipboardSection
                        
                        // Flavor text section
                        flavorTextSection
                        
                        // 1Password section
                        // onePasswordSection
                    }
                    .padding()
                }
                
                Divider()
                
                // Bottom action buttons
                HStack(spacing: 8) { // 1. Reduced spacing from 12 to 8
    Button("Disconnect") {
        onePassword.signOut()
    }
    .buttonStyle(.bordered)
    .controlSize(.large) // 2. Increased size preset
    .frame(maxWidth: .infinity)
    .frame(height: 44)   // 3. Increased height from 32 to 44
    
    Button("Quit") {
        NSApplication.shared.terminate(nil)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large) // 2. Increased size preset
    .frame(maxWidth: .infinity)
    .frame(height: 44)   // 3. Increased height from 32 to 44
}
.padding(.horizontal, 16)
.padding(.vertical, 12)
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
            
            // Set up the callback to trigger popup when API key is detected
            // This ensures popup shows even when isAPIKey doesn't change boolean value
            .onAppear {
                let onePasswordRef = onePassword
                clipboardManager.onAPIKeyDetected = {
                    guard onePasswordRef.isSignedIn else { return }
                    OnePasswordWindowManager.shared.showPopup(
                        clipboardManager: clipboardManager,
                        onePassword: onePasswordRef
                    )
                }
                
                // Fetch user info if already signed in
                if onePasswordRef.isSignedIn {
                    Task {
                        try? await onePasswordRef.getUserInfo()
                    }
                }
            }
            
            // Increment vulnerability counter when API key detected
            .onChange(of: clipboardManager.currentText) { _ in
                if clipboardManager.isAPIKey {
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
    
    // MARK: - Connection Status Bar
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(onePassword.isSignedIn ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(onePassword.isSignedIn ? "Connected to 1Password" : "Not connected")
                .font(.caption.weight(.semibold))
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
                if clipboardManager.isAPIKey {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(clipboardManager.currentText ?? "Empty")
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                    }
                }
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: clipboardManager.isAPIKey ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(clipboardManager.isAPIKey ? .green : .secondary)
                        Text(clipboardManager.isAPIKey ? "Looks like an API key" : "API key not detected")
                            .font(.caption)
                            .foregroundColor(clipboardManager.isAPIKey ? .primary : .secondary)
                    }
                    Spacer()
                }
            }
            .padding(4)
        }
    }
    
    // MARK: - Flavor Text Section
    private var flavorTextSection: some View {
        HStack {
            Spacer()
            Text("🛡️ We have stopped \(vulnerabilitiesStopped) data leaks!")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
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
                Task { await onePassword.signIn() }
            } label: {
                Label("Connect to 1Password", systemImage: "person.badge.key")
            }
            .buttonStyle(.borderedProminent)
            
            if !onePassword.checkCLIAvailable() {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.red)
                        Text("1Password CLI not found or not executable")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Install via: brew install 1password-cli")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var signedInView: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Button("Disconnect") { onePassword.signOut() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            Divider()
            
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

// MARK: - HELPER VIEWS (Main App)

struct VaultBadge: View {
    let name: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill").font(.caption2)
            Text(name).font(.caption)
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
                Section("Required") {
                    TextField("Title", text: $title).textFieldStyle(.roundedBorder)
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
                        SecureField("Enter or paste your API key", text: $credential).textFieldStyle(.roundedBorder)
                    }
                    Picker("Vault", selection: $selectedVault) {
                        ForEach(onePassword.availableVaults) { vault in
                            Text(vault.name).tag(vault.name)
                        }
                    }
                }
                Section("Optional") {
                    TextField("Username", text: $username).textFieldStyle(.roundedBorder)
                    TextField("Type", text: $credentialType).textFieldStyle(.roundedBorder)
                    TextField("Hostname / URL", text: $hostname).textFieldStyle(.roundedBorder)
                    TextField("Tags (comma-separated)", text: $tags).textFieldStyle(.roundedBorder)
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 60).font(.body)
                }
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            Text(error).foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add API Credential")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCredential() }
                    .disabled(title.isEmpty || credential.isEmpty || selectedVault.isEmpty || isSaving)
                }
            }
            .onAppear {
                if clipboardManager.isAPIKey, let text = clipboardManager.currentText { credential = text }
                if selectedVault.isEmpty, let firstVault = onePassword.availableVaults.first { selectedVault = firstVault.name }
            }
            .alert("Credential Saved!", isPresented: $showingSuccess) { Button("Done") { dismiss() } }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func saveCredential() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                let newCredential = OnePasswordCLI.NewAPICredential(title: title, vault: selectedVault, credential: credential, username: username.isEmpty ? nil : username, type: credentialType.isEmpty ? nil : credentialType, hostname: hostname.isEmpty ? nil : hostname, notes: notes.isEmpty ? nil : notes, tags: tagArray)
                try await onePassword.createAPICredential(newCredential)
                await MainActor.run {
                    clipboardManager.clearClipboard()
                    isSaving = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run { isSaving = false; errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - NEW POPUP SYSTEM (TWO WINDOWS)

// 1. The Small Proposal Window
struct ProposalView: View {
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
    
    // Computed property for save button disabled state
    private var isSaveDisabled: Bool {
        isSaving || itemName.isEmpty || selectedVault.isEmpty || clipboardManager.currentText == nil
    }
    
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
        
        Task { @MainActor in
            do {
                let credential = OnePasswordCLI.NewAPICredential(
                    title: itemName,
                    vault: selectedVault,
                    credential: token,
                    hostname: website.isEmpty ? nil : website,
                    tags: tags
                )
                
                _ = try await onePassword.createAPICredential(credential)
                
                // Update state with animation, wrapped in a small delay to avoid constraint conflicts
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds to let layout complete
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isSaving = false
                    showSuccess = true
                }
                
                // Auto-close after success and clear clipboard when window closes
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                // Clear clipboard when the card closes after successful save
                clipboardManager.clearClipboard()
                onClose()
            } catch {
                // Small delay before error state update
                try? await Task.sleep(nanoseconds: 50_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var collapsedState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(itemName)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 16)
                .padding(.top, 8)
            
            Text("Save in 1Password?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.leading, 16)
                .padding(.bottom, 4)
            
            HStack(spacing: 12) {
                Button("Dismiss") {
                    onClose()
                }
                .buttonStyle(DarkButtonStyle())
                
                // ContentView.swift - Inside struct ProposalView

                Button("Save item") {
                    // 1. Tell the window to expand first
                    onExpand(expandedSize)
                    
                    // 2. Wait for the window expansion to be well underway before
                    // switching the internal SwiftUI view to the expanded form.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        // Remove 'withAnimation' here to prevent SwiftUI from
                        // triggering a second, conflicting layout pass.
                        self.isExpanded = true
                    }
                }
                .buttonStyle(BlueButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }
    
    private var expandedState: some View {
        VStack(alignment: .leading, spacing: 15) {
            DarkTextField(label: "Name", text: $itemName)
            DarkDisabledField(label: "Token", text: tokenDisplay)
            
            DarkTagInput(
                label: "Tags",
                tags: $tags,
                tagInput: $tagInput
            )
            
            DarkVaultPicker(
                label: "Vault",
                selection: $selectedVault,
                vaults: onePassword.availableVaults
            )
            
            DarkTextField(label: "Website", text: $website)
            
            Spacer()
            
            // Show success/error message in place of buttons, or show buttons
            if showSuccess {
                successView
                    .transition(.scale.combined(with: .opacity))
            } else if let error = saveError {
                errorView(error)
                    .transition(.scale.combined(with: .opacity))
            } else {
                footerActions
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        // ADD THIS: Force the view to be exactly the expanded size
        // so the window doesn't have to calculate constraints
        .frame(width: expandedSize.width, height: expandedSize.height, alignment: .top)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func errorView(_ error: String) -> some View {
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
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(6)
    }
    
    private var successView: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text("Saved to 1Password!")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.15))
        .cornerRadius(6)
    }
    
    private var footerActions: some View {
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
            .disabled(isSaveDisabled)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.blue))
                    .font(.caption)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Group {
                if !isExpanded {
                    collapsedState
                } else {
                    expandedState
                }
            }
        }
        .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        .cornerRadius(12)
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

// --- SHARED STYLES ---

struct DarkTextField: View {
    var label: String
    @Binding var text: String
    var placeholder: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.gray)
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// --- WINDOW MANAGER ---

class OnePasswordWindowManager {
    static let shared = OnePasswordWindowManager()
    private var activePanel: NSPanel?
    
    func showPopup(clipboardManager: ClipboardManager, onePassword: OnePasswordCLI) {
        if activePanel != nil {
            activePanel?.makeKeyAndOrderFront(nil)
            return
        }
        
        let initialSize = NSSize(width: 340, height: 160)
        let panel = createPanel(width: initialSize.width, height: initialSize.height)
        panel.hasShadow = true
        
        // Inject View with Actions and Dependencies
        let contentView = ProposalView(
            onClose: { [weak self] in
                self?.closeWindow()
            },
            onExpand: { [weak panel] newSize in
                guard let panel = panel else { return }
                
                var frame = panel.frame
                let diff = newSize.height - frame.height
                frame.origin.y -= diff // Keep the top of the window in place while it grows down
                frame.size = newSize
                
                // Use a standard Animation Context which is more stable for NSHostingView
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    context.allowsImplicitAnimation = true
                    // Set the frame directly; allowsImplicitAnimation handles the smooth transition
                    panel.setFrame(frame, display: true, animate: true)
                }, completionHandler: {
                    // Ensure the layout engine is forced to sync after the animation finishes
                    panel.contentView?.needsLayout = true
                })
            },
            clipboardManager: clipboardManager,
            onePassword: onePassword
        )
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        present(panel)
    }
    
    // Shared Helper to create the transparent, borderless window
    private func createPanel(width: CGFloat, height: CGFloat) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Remove native UI elements
        panel.titlebarSeparatorStyle = .none
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        return panel
    }
    
    private func present(_ panel: NSPanel) {
        self.activePanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        activePanel?.close()
        activePanel = nil
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardManager())
}
