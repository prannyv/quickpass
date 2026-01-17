//
//  LoginView.swift
//  quickpass
//
//  Created by Chandler Xie on 2026-01-17.
//

import SwiftUI

struct LoginView: View {
    // This binding connects to the state in quickpassApp.swift to handle redirection
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Welcome to QuickPass")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Securely detect and save API keys.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                // Updates the parent state to trigger the redirect to ContentView
                isLoggedIn = true
            }) {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Login to 1Password")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
            
            // FIX: Changed .foregroundColor(.tertiaryLabel) to .foregroundStyle(.tertiary)
            Text("No authentication required for this preview.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }
}
