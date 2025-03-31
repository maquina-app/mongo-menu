#!/bin/bash

# Exit on any error
set -e

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if MongoDB binaries exist
MONGODB_DIR="$PROJECT_DIR/MongoMenu/Resources/mongodb"
if [ ! -d "$MONGODB_DIR" ] || [ ! -f "$MONGODB_DIR/bin/mongod" ]; then
	echo "MongoDB binaries not found. Running download script first..."
	"$SCRIPT_DIR/download_mongodb.sh"
fi

# Clean previous build
echo "Cleaning previous build..."
rm -rf "$PROJECT_DIR/build"

# Build the app
echo "Building MongoMenu app..."
cd "$PROJECT_DIR"
xcodebuild -project MongoMenu.xcodeproj -scheme MongoMenu -configuration Release build

# Check if build was successful
if [ -d "$PROJECT_DIR/build/Release/MongoMenu.app" ]; then
	echo "✅ Build completed successfully!"
	echo "App location: $PROJECT_DIR/build/Release/MongoMenu.app"

	# Option to open the folder containing the app
	read -p "Do you want to open the folder containing the app? (y/n) " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		open "$PROJECT_DIR/build/Release"
	fi
else
	echo "❌ Build failed. Check the logs above for errors."
	exit 1
fi
