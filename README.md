# SpeechToCode

A macOS application that enables voice control for coding environments using Claude Code CLI, featuring a streamlined installation process for all dependencies.

## Features

- Integrated Claude Code CLI for AI-powered code generation
- Voice command processing for code editing and creation
- Automatic Node.js and Claude Code installation with progress tracking
- Interactive terminal interface for direct Claude Code interaction
- Robust environment configuration to ensure consistent behavior
- Persistent installation state management using SwiftData

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+
- Internet connection for dependency downloads

## Installation

1. Clone the repository
2. Open the Xcode project
3. Build and run the application
4. The app will automatically install Node.js and Claude Code

## Project Structure

- **Models**: Data models for tracking installation state and Claude interactions
- **Services**: Core services for dependency installation and Claude Code integration
- **Views**: SwiftUI interface components including terminal and voice input
- **Utilities**: Helper classes and extensions for file management and process execution

## Development Notes

For detailed information about the installation process, see [INSTALLATION.md](INSTALLATION.md).

For information about the current development branch and upcoming features, see [BRANCH.md](BRANCH.md).

## License

This project is licensed under the MIT License - see the LICENSE file for details.
