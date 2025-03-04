# SpeechToCode - Project Specification

## Project Overview

SpeechToCode is a macOS application that integrates voice control capabilities with code generation tools. It allows developers to write, edit, and manipulate code using voice commands, making coding more accessible and efficient.

The app provides a bridge between voice recognition systems and code generation tools like Claude Code CLI, handling the installation, management, and execution of required dependencies.

## Core Components

### 1. Installation System

The application handles the automated installation of required dependencies:

- **Node.js**: Automatically downloads and installs the appropriate Node.js version for the user's system
- **Claude Code CLI**: Installs the Claude Code package locally with proper environment configuration
- **Environment Setup**: Configures PATH and NODE_PATH variables to ensure consistent behavior

Installation progress and status are tracked in the app's persistence layer using SwiftData.

### 2. Voice Recognition

The app integrates with macOS voice recognition capabilities to:
- Capture and process voice commands
- Translate speech into actionable code operations
- Provide feedback on recognized commands

### 3. Code Generation

Once dependencies are installed, the app facilitates:
- Code generation based on voice prompts via Claude Code CLI
- Code editing through voice commands
- Code execution and output display
- Contextual understanding of project structure

### 4. UI Components

- **ContentView**: Main application view that coordinates the overall UI
- **InstallationView**: Handles the visualization of installation progress
- **ClaudeTerminalView**: Provides direct terminal interface to Claude Code CLI 
- **CodeEditorView**: Provides the interface for code editing and generation

## Architecture

### Models

- **InstallationState**: Tracks the installation status of Node.js and Claude Code
  - Stores paths to executables and package directories
  - Persists version information for installed components
- **AppState**: Maintains the overall application state
- **Item**: Basic model for app data items

### Services

- **InstallationManager**: Coordinates the installation of dependencies
- **NodeInstaller**: Handles downloading and installing Node.js
  - Provides a common installation directory under Application Support
  - Ensures consistent installation location across app launches
  - Handles platform-specific requirements (arm64/x86_64)
- **ClaudeCodeService**: Manages interaction with the Claude Code CLI
  - Sets up proper environment variables for CLI execution
  - Handles terminal I/O for Claude Code sessions
  - Provides terminal interface for direct interaction
- **NpmPackageInstaller**: Manages npm package installations
- **AppStateManager**: Handles the application state persistence and retrieval
- **ProcessRunner**: Executes commands with proper environment configuration

### Utilities

- **ProcessRunner**: Facilitates running external processes with proper output capture
- **Logger**: Provides application-wide logging capabilities with configurable verbosity
- **FileManager Extensions**: Handle file permissions and executable verification

## Dependencies

1. **SwiftUI**: For building the user interface
2. **SwiftData**: For data persistence
3. **Combine**: For reactive programming patterns
4. **OSLog**: For system logging integration
5. **@anthropic-ai/claude-code**: npm package for AI-powered code generation

## Installation and Setup

The application handles its own setup automatically, including:

1. Checking for existing Node.js installations
2. Downloading and installing Node.js if needed
3. Creating package.json and installing Claude Code package locally
4. Setting up proper environment variables for terminal sessions
5. Verifying installations through version checks

## Development Environment

- **Xcode**: Primary development environment
- **Swift 5.10+**: Programming language
- **macOS 14.0+**: Target operating system

## Testing Strategy

- **Unit Tests**: Cover core functionality like package installation
  - **NodeInstallerTests**: Verify Node.js installation and common directory functionality
  - **NpmPackageInstallerTests**: Test npm package installation capabilities
  - **ClaudeCodeServiceTests**: Verify Claude Code CLI interaction
- **UI Tests**: Verify the application's interface and user flows

## Future Enhancements

1. Project context management for improved code generation
2. Enhanced voice command processing pipeline for specialized programming languages
3. Multi-language support
4. Collaborative coding features with shared terminal sessions
