#!/bin/bash

# Exit on any error
set -e

# Define MongoDB version (can be overridden by package.json if it exists)
DEFAULT_MONGO_VERSION="8.0.6"
MONGO_VERSION=$DEFAULT_MONGO_VERSION

echo "Using MongoDB version $MONGO_VERSION"

# Define URLs and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/MongoMenu/Resources"

# Check for Apple Silicon vs Intel
if [[ $(uname -m) == 'arm64' ]]; then
	ARCH="aarch64"
	MONGO_URL="https://fastdl.mongodb.org/osx/mongodb-macos-arm64-$MONGO_VERSION.tgz"
else
	ARCH="x86_64"
	MONGO_URL="https://fastdl.mongodb.org/osx/mongodb-macos-x86_64-$MONGO_VERSION.tgz"
fi

TMP_DIR="$PROJECT_DIR/tmp"
TARBALL="$TMP_DIR/mongodb-macos-$ARCH-$MONGO_VERSION.tgz"
EXTRACTED_DIR="$TMP_DIR/mongodb-macos-$ARCH-$MONGO_VERSION"
DEST_DIR="$RESOURCES_DIR/mongodb"

echo "Architecture: $ARCH"
echo "MongoDB URL: $MONGO_URL"

# Create temp directory
mkdir -p "$TMP_DIR"

# Download MongoDB tarball
echo "Downloading MongoDB $MONGO_VERSION for macOS $ARCH..."
curl -o "$TARBALL" "$MONGO_URL"

# Extract tarball
echo "Extracting MongoDB..."
tar -xzf "$TARBALL" -C "$TMP_DIR"

# Create Resources directory if it doesn't exist
mkdir -p "$RESOURCES_DIR"

# Copy extracted files to destination
echo "Copying files to $DEST_DIR..."
mkdir -p "$DEST_DIR"
cp -a "$EXTRACTED_DIR/." "$DEST_DIR/"

# Make binaries executable
echo "Setting executable permissions..."
chmod +x "$DEST_DIR/bin/"*

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo "✅ MongoDB $MONGO_VERSION for macOS $ARCH has been downloaded and prepared successfully."
echo "Location: $DEST_DIR"
