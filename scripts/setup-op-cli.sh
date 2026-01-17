#!/bin/bash
#
# setup-op-cli.sh
# Downloads and sets up the 1Password CLI for bundling with QuickPass
#
# Usage: ./scripts/setup-op-cli.sh
#

set -e

# Configuration
OP_VERSION="2.30.0"  # Update this to the latest stable version
ARCH=$(uname -m)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_ROOT/quickpass/quickpass/Resources"

# Determine architecture
if [ "$ARCH" = "arm64" ]; then
    OP_ARCH="arm64"
elif [ "$ARCH" = "x86_64" ]; then
    OP_ARCH="amd64"
else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi

echo "🔧 Setting up 1Password CLI v${OP_VERSION} for ${OP_ARCH}..."

# Create Resources directory if it doesn't exist
mkdir -p "$RESOURCES_DIR"

# Download URL
DOWNLOAD_URL="https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_VERSION}/op_apple_universal_v${OP_VERSION}.pkg"

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📥 Downloading 1Password CLI..."
curl -sSL "$DOWNLOAD_URL" -o "$TEMP_DIR/op.pkg"

echo "📦 Extracting..."
# Extract the pkg
cd "$TEMP_DIR"
xar -xf op.pkg

# Find and extract the payload
cat op.pkg.tmp/Payload | gunzip -dc | cpio -i 2>/dev/null || true

# The op binary should be in usr/local/bin/op
if [ -f "usr/local/bin/op" ]; then
    cp "usr/local/bin/op" "$RESOURCES_DIR/op"
    chmod +x "$RESOURCES_DIR/op"
    echo "✅ 1Password CLI installed to: $RESOURCES_DIR/op"
else
    echo "❌ Failed to extract op binary from package"
    echo "   Trying alternative extraction method..."
    
    # Alternative: use pkgutil
    pkgutil --expand-full op.pkg "$TEMP_DIR/expanded" 2>/dev/null || true
    
    OP_BINARY=$(find "$TEMP_DIR" -name "op" -type f 2>/dev/null | head -1)
    if [ -n "$OP_BINARY" ]; then
        cp "$OP_BINARY" "$RESOURCES_DIR/op"
        chmod +x "$RESOURCES_DIR/op"
        echo "✅ 1Password CLI installed to: $RESOURCES_DIR/op"
    else
        echo "❌ Could not find op binary in package"
        echo ""
        echo "Please manually download from:"
        echo "  https://developer.1password.com/docs/cli/get-started/"
        echo ""
        echo "Then copy the 'op' binary to:"
        echo "  $RESOURCES_DIR/op"
        exit 1
    fi
fi

# Verify the binary
if "$RESOURCES_DIR/op" --version > /dev/null 2>&1; then
    VERSION=$("$RESOURCES_DIR/op" --version)
    echo "✅ Verified: 1Password CLI $VERSION"
else
    echo "⚠️  Binary copied but verification failed (this may be normal on first run)"
fi

echo ""
echo "📋 Next steps:"
echo "   1. Open your Xcode project"
echo "   2. Select your target → Build Phases → Copy Bundle Resources"
echo "   3. Add the 'op' binary from Resources folder"
echo "   4. Or add a 'Run Script' build phase to copy it automatically"
echo ""
echo "🔐 Users will need to:"
echo "   1. Have 1Password desktop app installed"
echo "   2. Enable 'Integrate with 1Password CLI' in Settings → Developer"
echo ""

