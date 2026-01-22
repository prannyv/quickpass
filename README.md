# QuickPass

Save your API keys to 1Password automatically, hassle-free.

QuickPass monitors your clipboard and detects when you copy an API key (using entropy-based detection). With one click, save it directly to your 1Password vault.

<img width="427" height="479" alt="IMG_2745" src="https://github.com/user-attachments/assets/7b7b757c-f416-465d-9311-5930427ded8d" />


## Features

- **Clipboard Monitoring**: Automatically detects API keys based on Shannon entropy
- **1Password Integration**: Securely saves credentials using 1Password CLI with desktop app integration
- **Privacy-First**: No servers, no callbacks, everything runs locally
- **Biometric Auth**: Uses Touch ID / password via 1Password desktop app

<img width="360" height="157" alt="IMG_2439" src="https://github.com/user-attachments/assets/0aa1aac3-3f41-4c8f-bbd1-d1a25d8e86f9" />
<img width="397" height="474" alt="IMG_7280" src="https://github.com/user-attachments/assets/ca90b1c8-01be-48cf-9002-bd4a3003426e" />


## Requirements

- macOS 13.0+
- 1Password 8+ desktop app
- 1Password CLI (bundled with app, or system-installed)

## Setup

### 1. Enable 1Password CLI Integration

1. Open **1Password** desktop app
2. Go to **Settings** → **Developer**
3. Enable **"Integrate with 1Password CLI"**

### 2. Build & Run

```bash
# Clone the repository
git clone https://github.com/your-username/quickpass.git
cd quickpass

# Download and bundle the 1Password CLI (optional - falls back to system install)
chmod +x scripts/setup-op-cli.sh
./scripts/setup-op-cli.sh

# Open in Xcode
open quickpass/quickpass.xcodeproj
```

### 3. Add op Binary to Xcode (if bundling)

If you want to bundle the `op` CLI with your app:

1. In Xcode, select your target → **Build Phases**
2. Expand **Copy Bundle Resources**
3. Click **+** and add `Resources/op`
4. Or add a **Run Script** phase:

```bash
# Copy op binary to app bundle
cp "${PROJECT_DIR}/quickpass/Resources/op" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/op"
chmod +x "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/op"
```

## Usage

1. **Connect to 1Password**: Click "Connect to 1Password" and authenticate with Touch ID or your password
2. **Copy an API Key**: Copy any API key to your clipboard
3. **Save**: QuickPass will detect it and show "Save to 1Password" button
4. **Fill Details**: Add a title, select vault, and optionally add metadata
5. **Done**: Your credential is securely stored in 1Password

## Architecture

```
quickpass/
├── ClipboardManager.swift   # Monitors clipboard, detects API keys via entropy
├── OnePasswordCLI.swift     # 1Password CLI wrapper (Process-based)
├── ContentView.swift        # Main UI with login & credential management
├── quickpassApp.swift       # App entry point
└── Resources/
    └── op                   # Bundled 1Password CLI binary (optional)
```

### 1Password CLI Integration

QuickPass uses the [1Password CLI](https://developer.1password.com/docs/cli/) with desktop app integration:

- **Authentication**: Via biometric (Touch ID) or 1Password master password
- **Sessions**: Managed by 1Password app (10min idle timeout, 12hr max)
- **Security**: CLI uses XPC with code signature verification

The app looks for `op` binary in this order:
1. App bundle Resources folder
2. App bundle MacOS folder  
3. `/usr/local/bin/op` (system install)
4. `/opt/homebrew/bin/op` (Homebrew ARM)

### API Credential Fields

When saving an API credential, you can specify:

| Field | Description |
|-------|-------------|
| **Title** | Name of the credential (required) |
| **Credential** | The API key/token value (required) |
| **Vault** | Which vault to save to (required) |
| Username | Associated username |
| Type | e.g., "production", "development" |
| Hostname | Associated service URL |
| Notes | Additional information |
| Tags | Comma-separated tags |

## Privacy & Security

- **No External Servers**: Everything runs locally on your Mac
- **End-to-End Encryption**: Credentials are encrypted by 1Password
- **Biometric Protection**: Requires Touch ID or password to access vaults
- **Session Management**: Sessions expire after inactivity
- **Code Signing**: 1Password verifies CLI caller identity

## Troubleshooting

### "1Password CLI not found"

The app couldn't find the `op` binary. Solutions:

1. **Bundle it**: Run `./scripts/setup-op-cli.sh` and add to Xcode
2. **Install system-wide**: 
   ```bash
   brew install 1password-cli
   ```

### "Please enable 'Integrate with 1Password CLI'"

1. Open 1Password desktop app
2. Go to Settings → Developer
3. Toggle on "Integrate with 1Password CLI"

### "Not signed in to 1Password"

1. Ensure 1Password desktop app is running
2. Make sure you're signed in to your 1Password account
3. Try clicking "Connect to 1Password" again

### Session expired

Sessions expire after ~10 minutes of inactivity. Simply reconnect by clicking the login button again.

## Development

### Building

```bash
# Build for development
xcodebuild -scheme quickpass -configuration Debug build

# Build for release
xcodebuild -scheme quickpass -configuration Release build
```

### Testing CLI Integration

```bash
# Test op CLI manually
op vault list --format json
op item create --category "API Credential" --title "Test" --vault "Private" credential="test123"
```

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [1Password](https://1password.com) for their excellent CLI and desktop app integration
- Shannon entropy algorithm for API key detection
