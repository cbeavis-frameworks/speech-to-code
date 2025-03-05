#!/bin/bash

# Script to build and run the SpeechToCode app
echo "Building and running SpeechToCode app..."

# Make sure terminal_helper.sh is executable
chmod +x terminal_helper.sh

# Navigate to the project directory
cd "$(dirname "$0")"

# Use xcodebuild to build the app
xcodebuild -scheme SpeechToCode -configuration Debug -destination 'platform=macOS' build

# If the build was successful, run the app
if [ $? -eq 0 ]; then
    echo "Build successful! Running the app..."
    open ./build/Debug/SpeechToCode.app
else
    echo "Build failed. Please check the error messages above."
fi
