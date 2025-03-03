# SpeechToCode - Project Specification

## Project Overview

SpeechToCode is a macOS application that integrates voice control capabilities with code generation tools. It allows developers to write, edit, and manipulate code using voice commands, making coding more accessible and efficient.

The app provides a bridge between voice recognition systems and code generation tools like Claude Code CLI, handling the installation, management, and execution of required dependencies.

## Core Components

### 1. Installation System

The application handles the automated installation of required dependencies:

- **Node.js**: Automatically downloads and installs the appropriate Node.js version for the user's system
- **npm Packages**: Installs necessary npm packages, particularly `@anthropic-ai/claude-code`

Installation progress and status are tracked in the app's persistence layer using SwiftData.

### 2. Voice Recognition

The app integrates with macOS voice recognition capabilities to:
- Capture and process voice commands
- Translate speech into actionable code operations
- Provide feedback on recognized commands

### 3. Code Generation

Once dependencies are installed, the app facilitates:
- Code generation based on voice prompts
- Code editing through voice commands
- Code execution and output display

### 4. UI Components

- **ContentView**: Main application view that coordinates the overall UI
- **InstallationView**: Handles the visualization of installation progress
- **CodeEditorView**: Provides the interface for code editing and generation

## Architecture

### Models

- **InstallationState**: Tracks the installation status of Node.js
- **AppState**: Maintains the overall application state
- **Item**: Basic model for app data items

### Services

- **InstallationManager**: Coordinates the installation of dependencies
- **NodeInstaller**: Handles downloading and installing Node.js
- **NpmPackageInstaller**: Manages npm package installations
- **AppStateManager**: Handles the application state persistence and retrieval

### Utilities

- **ProcessRunner**: Facilitates running external processes with proper output capture
- **Logger**: Provides application-wide logging capabilities with configurable verbosity

## Dependencies

1. **SwiftUI**: For building the user interface
2. **SwiftData**: For data persistence
3. **Combine**: For reactive programming patterns
4. **OSLog**: For system logging integration

## Installation and Setup

The application handles its own setup automatically, including:

1. Checking for existing Node.js installations
2. Downloading and installing Node.js if needed
3. Installing required npm packages
4. Verifying installations through version checks

## Development Environment

- **Xcode**: Primary development environment
- **Swift 5.10+**: Programming language
- **macOS 14.0+**: Target operating system

## Testing Strategy

- **Unit Tests**: Cover core functionality like package installation
- **UI Tests**: Verify the application's interface and user flows

## Future Enhancements

1. Enhanced voice command recognition for specialized programming languages
2. Multi-language support
3. Integration with additional code generation tools
4. Collaborative coding features
