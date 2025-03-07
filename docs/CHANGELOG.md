# Changelog

All notable changes to the SpeechToCode project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2025-03-07

### Added
- AI Agent Models implementation (Phase 1.3)
- AgentMessage model for structured agent communication
- RealtimeSession model for OpenAI Realtime API integration
- ConversationAgent model for user interaction and workflow orchestration
- PlanningAgent model for project context and long-term memory
- FileBasedPlanStorage implementation for persistence
- test-phase-1-3.swift command-line test script

## [0.4.0] - 2025-03-06

### Added
- Terminal Controller enhancements for Claude Code CLI integration (Phase 1.2)
- ClaudeHelper.swift for managing Claude CLI interactions
- Claude-specific command support in TerminalController
- Detection for Claude Code interactive prompts
- Claude Code command history tracking
- Specialized response parsing for Claude Code output
- Claude CLI integration tests
- Enhanced terminal_helper.sh with Claude-specific functions

## [0.3.0] - 2025-03-06

### Added
- Project configuration for multi-agent architecture (Phase 1.1)
- OpenAI API client dependencies (WebSocketKit, NIO, AsyncHTTPClient)
- Config.swift for managing API keys and settings
- Environment variables setup with .env.template
- Updated entitlements for network access, file access, and microphone access
- Usage descriptions in Info.plist for microphone and speech recognition
- ConfigurationTests.swift for testing project configuration
- test-phase-1-1.swift command-line test script

### Changed
- Updated .gitignore to exclude .env file with sensitive API keys
- Updated SPEC.md to include multi-agent architecture details
- Updated plan.txt to mark Phase 1.1 as completed

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
