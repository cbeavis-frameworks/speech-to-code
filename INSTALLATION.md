# SpeechToCode Installation Guide

This document provides technical details about the installation process implemented in the SpeechToCode application.

## Overview

SpeechToCode handles installation of its dependencies automatically, providing users with a seamless setup experience. The primary dependencies are Node.js and the Claude Code CLI, which power the code generation capabilities.

## Installation Components

### 1. Node.js Installation

The `NodeInstaller` service handles the installation of Node.js:

- Determines the appropriate Node.js version based on system architecture
- Downloads the Node.js binary from the official source
- Extracts and installs Node.js to the application's support directory
- Verifies the installation by checking the npm version

### 2. Claude Code Package Installation

The `InstallationManager` ensures that the Claude Code CLI is properly installed:

- Creates a package.json in the installation directory
- Installs the Claude Code package locally (not globally)
- Validates the installation with version checks
- Sets up proper paths for terminal interaction with Claude Code

### 3. Environment Setup

The `ClaudeCodeService` handles proper environment configuration:

- Sets up PATH to include the Node.js bin directory
- Configures NODE_PATH to find local packages
- Ensures terminal sessions can locate and use the Claude Code CLI
- Provides fallback searching to handle different installation locations

## Installation Path

Dependencies are installed in the application's support directory:

```
~/Library/Application Support/com.theframeworks.SpeechToCode/bin/
```

The Node.js binary is located at:
```
~/Library/Application Support/com.theframeworks.SpeechToCode/bin/node-18.17.1/bin/node
```

The Claude Code package is installed at:
```
~/Library/Application Support/com.theframeworks.SpeechToCode/bin/node-18.17.1/lib/node_modules/@anthropic-ai/claude-code
```

This ensures a consistent environment for the app regardless of whether the user has Node.js installed elsewhere on their system.

## Development and Debugging Mode

During development, the app includes an automatic cleanup feature that:

1. Removes all Node.js and npm package installations
2. Resets the installation state in SwiftData
3. Clears the NodePath singleton

This cleanup happens automatically when the app launches in DEBUG mode, allowing developers to test the installation process with each run. This feature can be disabled by setting `AppCleanupService.cleanOnLaunch = false` in SpeechToCodeApp.swift.

## Installation State Tracking

The `InstallationState` model tracks:

- Whether Node.js and Claude Code are installed
- The path to the Node.js binary
- The path to the Claude Code package directory
- The installed Node.js and Claude Code versions

This state is persisted using SwiftData and used to determine if installation steps need to be performed when the app launches.

## Common Installation Issues

### 1. Permission Problems

If the app cannot write to the Application Support directory, installation will fail. The app requires proper permissions to install dependencies.

### 2. Network Connectivity

Node.js installation requires internet connectivity to download the binary. If the network is unavailable, installation will fail.

### 3. Disk Space

The Node.js installation requires approximately 100MB of free disk space. Installation will fail if there is insufficient space.

### 4. Package Location Mismatch

If the Claude Code CLI cannot be found at runtime, it's usually because there's a mismatch between where the package was installed and where the terminal is looking for it. The app now handles this by configuring NODE_PATH to include multiple potential locations.

## npm Package Details

The following npm packages are used by the application:

- `@anthropic-ai/claude-code`: The Claude Code CLI tool that powers the code generation and voice command processing. This package is installed locally within the node installation directory rather than globally.
