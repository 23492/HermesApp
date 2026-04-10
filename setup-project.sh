#!/bin/bash

# HermesApp Project Setup Script
# This script sets up the HermesApp Xcode project using XcodeGen

set -e

echo "🚀 Setting up HermesApp Xcode Project..."

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ Homebrew not found. Please install XcodeGen manually:"
        echo "   brew install xcodegen"
        exit 1
    fi
else
    echo "✅ XcodeGen is already installed"
fi

# Navigate to project directory
cd "$(dirname "$0")"

echo "📁 Project directory: $(pwd)"

# Generate Xcode project
echo "🔨 Generating Xcode project..."
xcodegen generate

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Success! Xcode project generated."
    echo ""
    echo "Next steps:"
    echo "   1. Open HermesApp.xcodeproj in Xcode"
    echo "   2. Select 'My Mac' or iOS Simulator as target"
    echo "   3. Build and run with Cmd+R"
    echo ""
    echo "   Or run: open HermesApp.xcodeproj"
else
    echo "❌ Failed to generate Xcode project"
    exit 1
fi
