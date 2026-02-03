#!/bin/bash
set -e

# macOS install script for metal-cli
INSTALL_DIR="/usr/local/bin"
REPO="tether-labs/metal"
VERSION="v1.0.6"
TARBALL="metal-1.0.6-darwin-arm64.tar.gz"
BINARY_NAME="metal"

echo "Installing Metal Cli..."

# Check if running on Apple Silicon
if [[ $(uname -m) != "arm64" ]]; then
    echo "Error: This installer is for Apple Silicon Macs only"
    exit 1
fi

# Download the release tarball with error checking
echo "Downloading $TARBALL..."
if ! curl -L -o /tmp/$TARBALL https://github.com/$REPO/releases/download/$VERSION/$TARBALL; then
    echo "Error: Failed to download release tarball"
    echo "Make sure the release asset exists at: https://github.com/$REPO/releases/tag/$VERSION"
    exit 1
fi

# Check if download was successful (file size > 100 bytes)
if [[ $(stat -f%z /tmp/$TARBALL 2>/dev/null || echo 0) -lt 100 ]]; then
    echo "Error: Downloaded file is too small (likely an error page)"
    echo "Check if the release asset exists: https://github.com/$REPO/releases/tag/$VERSION"
    rm -f /tmp/$TARBALL
    exit 1
fi

cd /tmp
tar -xzf $TARBALL

# Copy binary from the extracted structure
sudo cp metal-1.0.6-darwin-arm64/bin/$BINARY_NAME $INSTALL_DIR/
sudo chmod +x $INSTALL_DIR/$BINARY_NAME

# Cleanup
rm -rf /tmp/$TARBALL /tmp/metal-1.0.6-darwin-arm64

echo "Metal installed successfully!"
echo "You can now run: metal"
