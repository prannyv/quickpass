//
//  LoginView.swift
//  quickpass
//
//  Created by Chandler Xie on 2026-01-17.
//

import SwiftUI

struct LoginView: View {
    // This binding connects to the state in quickpassApp.swift to handle redirection
    @EnvironmentObject var onePassword: OnePasswordCLI
    
    var body: some View {
        VStack(spacing: 30) {
            // MARK: - Header Branding
            VStack(spacing: 15) {
                // Large icon with a gradient for a modern look
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 5) {
                    Text("Zapi")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }
            }
            .padding(.top, 10)

            // MARK: - Description
            Text("Automatically detect and save your API keys to your vaults with one click.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // MARK: - Action Button
            Button(action: {
                Task {
                    await onePassword.signIn() // Triggers the 1Password prompt
                }
            }) {
                HStack(spacing: 10) {
                    if onePassword.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "key.fill")
                    }
                    
                    Text(onePassword.isLoading ? "Connecting..." : "Connect to 1Password")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
            .disabled(onePassword.isLoading) // Disable during active sign-in

            // MARK: - Footer Info
            VStack(spacing: 4) {
                Text("Requires 1Password CLI integration enabled.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary) // Use .tertiary for the subtle footer look
                
                Link("Learn how to set up", destination: URL(string: "https://developer.1password.com/docs/cli/")!)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(40)
        .frame(width: 400, height: 450)
    }
}
