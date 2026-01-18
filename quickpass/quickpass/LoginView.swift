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
                // ... (keep your existing header icons and text)

                Button(action: {
                    Task {
                        await onePassword.signIn() // This triggers the 1Password prompt
                    }
                }) {
                    HStack {
                        if onePassword.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "key.fill")
                            Text("Connect to 1Password")
                                .fontWeight(.medium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(onePassword.isLoading)

                Text("Requires 1Password CLI integration enabled.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(40)
        }
}
