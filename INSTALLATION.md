# SpeechToCode Installation Guide

This document provides technical details about the installation process implemented in the SpeechToCode application.

## Overview

SpeechToCode handles installation of its dependencies automatically, providing users with a seamless setup experience. The primary dependency is Node.js, which is required to run the Claude Code CLI tool that powers the code generation capabilities.

## Installation Components

### 1. Node.js Installation

The `NodeInstaller` service handles the installation of Node.js:

- Determines the appropriate Node.js version based on system architecture
- Downloads the Node.js binary from the official source
- Extracts and installs Node.js to the application's support directory
- Verifies the installation by checking the npm version

### 2. npm Package Installation

The `NpmPackageInstaller` service handles the installation of required npm packages:

- Installs packages with specific versions as needed
- Provides retry mechanisms for reliability
- Handles locking to prevent concurrent npm operations
- Verifies installations to ensure they were successful

## Installation Path

Node.js is installed in the application's support directory:

```
~/Library/Application Support/SpeechToCode/bin/
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

- Whether Node.js is installed
- The path to the Node.js binary
- The installation directory
- The installed Node.js version

This state is persisted using SwiftData and used to determine if installation steps need to be performed when the app launches.

## Common Installation Issues

### 1. Permission Problems

If the app cannot write to the Application Support directory, installation will fail. The app requires proper permissions to install dependencies.

### 2. Network Connectivity

Node.js installation requires internet connectivity to download the binary. If the network is unavailable, installation will fail.

### 3. Disk Space

The Node.js installation requires approximately 100MB of free disk space. Installation will fail if there is insufficient space.

### 4. Concurrent npm Operations

npm can have issues with concurrent operations. The app implements locking mechanisms to prevent this, with a 1.5-second delay between operations to ensure stability.

## Manual Installation

While the app handles installation automatically, users can also manually install dependencies:

1. Install Node.js from the official website (https://nodejs.org/)
2. Install the Claude Code CLI: `npm install -g @anthropic-ai/claude-code@0.2.30`

The app will detect these manual installations if they are in the standard locations.

## npm Package Details

The following npm packages are used by the application:

- `@anthropic-ai/claude-code`: The Claude Code CLI tool that powers the code generation and voice command processing. This package is installed locally within the app's bin directory rather than globally.
