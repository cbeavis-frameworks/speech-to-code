# Changelog

All notable changes to the SpeechToCode project will be documented in this file.

## [Unreleased]

## [0.2.0] - 2025-03-03

### Added
- New MutexActor implementation for async-safe locking
- Controls for console logging verbosity
- Flag to enable/disable verbose context in logs
- Customizable logging levels for different parts of the application
- Testing with Claude Code CLI npm package

### Changed
- Simplified the installation process to focus only on Node.js
- Reduced logging verbosity to show only essential information
- Increased npm operation delay from 1.0s to 1.5s for improved reliability
- Improved Node.js path detection with more deterministic approach
- Updated tests to disable console logging for cleaner output

### Removed
- All Claude Code installation logic (ClaudeCodeInstaller.swift)
- Redundant logging in ProcessRunner
- Unnecessary status messages during npm operations
- Verbose file paths from logs

### Fixed
- Addressed Swift 6 compatibility issues by replacing NSLock
- Reduced duplicate log messages
- Eliminated console flooding with debug information
- Fixed potential race conditions in npm operations

## [0.1.0] - 2025-03-01

### Added
- Initial application structure
- Basic Node.js installation functionality
- npm package installation capabilities
- Simple UI for installation progress
- SwiftData integration for state persistence
- Preliminary voice command processing

### Changed
- None (initial release)

### Removed
- None (initial release)

### Fixed
- None (initial release)
