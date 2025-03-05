# Changelog

All notable changes to the SpeechToCode project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-03-05

### Added
- Terminal Controller feature for interacting with Terminal.app
- TerminalView UI component with command input and interactive controls
- terminal_helper.sh script for reliable Terminal interaction
- Interactive prompt detection and handling
- Keystroke simulation for responding to Terminal prompts
- Terminal output summarization
- Quick command buttons for common Terminal commands
- Custom keystroke input for advanced Terminal interaction
- Test script (test_terminal.sh) for verifying Terminal interaction
- build_and_run.sh script for easy building and running of the app

### Changed
- Updated ContentView to include TerminalView in a TabView
- Modified SpeechToCode.entitlements to include AppleScript automation permissions
- Updated Info.plist with usage descriptions for required permissions

### Fixed
- Improved command sending reliability by using keystroke simulation with automatic Return key
- Enhanced interactive prompt detection with more comprehensive patterns
- Fixed Terminal activation issues with proper delays and checks

## [0.1.0] - 2025-02-15

### Added
- Initial application structure
- Basic UI with item list view
- Core data integration for item storage
- SwiftUI-based user interface
- Basic speech recognition capabilities
- Initial project setup and configuration
