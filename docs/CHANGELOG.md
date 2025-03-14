# Changelog

All notable changes to the SpeechToCode project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Phase 5.4: UI Enhancements and Compatibility Fixes
  - Enhanced AgentStatusView to handle all agent types without type casting errors
  - Fixed OnboardingView implementation for macOS compatibility with improved transitions
  - Created reusable UI components for agent status display
  - Implemented proper SwiftUI state management for all views
  - Added improved UI for workflow status monitoring
  - Fixed compilation errors in test script by converting to demonstration app
  - Ensured macOS compatibility for all UI components
  - Completed integration of workflow automation features with UI elements
- Phase 5.3: Workflow Automation
  - Implemented WorkflowManager class to manage automated workflows
  - Created workflow templates for common development tasks (code review, project setup, etc.)
  - Added task execution sequences with progress tracking
  - Implemented workflow customization and reporting features
  - Enhanced AgentOrchestrator to integrate with WorkflowManager
  - Added comprehensive workflow state management and error handling
  - Created test script (test-phase-5-3.swift) to verify workflow automation functionality
  - Added support for pausing, resuming, and cancelling workflows
- Phase 5.2: Context Management
  - Implemented ContextManager class to facilitate context sharing between agents
  - Added project context initialization from planning agent
  - Created context refreshing mechanisms with automatic updates
  - Implemented conversation context summarization for efficient token usage
  - Integrated context-aware messaging in ConversationAgent
  - Added proper async handling for context retrieval operations
  - Fixed compilation errors in PlanningAgent implementation
- Phase 5.1: Multi-Agent Orchestration
  - Implemented AgentOrchestrator to manage agent connections and lifecycle
  - Created SessionManager for API connections and reconnection handling
  - Added coordinated startup and shutdown sequences for all system components
  - Implemented comprehensive error handling and recovery mechanisms
  - Added state monitoring across all components with proper Equatable conformance
  - Created self-contained test suite with mock implementations in test-phase-5-1.swift
  - Enhanced agent communication with improved message routing
  - Implemented pending task tracking for graceful shutdown
- Phase 4.3: Automated Decision Making
  - Implemented a decision tree for responding to common Claude prompts
  - Added automated response system for non-critical Claude CLI interactions
  - Created pattern recognition for detecting common prompt types
  - Implemented safety checks to prevent auto-responding to critical operations
  - Enhanced ClaudeHelper with context-aware decision making
  - Added comprehensive test suite for validating decision making logic
- Phase 4.2: Command Routing for Claude Code
  - Implemented intelligent command routing between terminal and Claude Code
  - Added detection logic to identify code-related queries and commands
  - Enhanced TerminalController with command queuing system for Claude initialization
  - Added response type classification to better process Claude outputs
  - Updated ClaudeHelper with direct command routing capabilities
- Phase 4.1: Claude CLI Setup
  - Implemented Claude CLI session management in ClaudeHelper class
  - Added authentication handling for Claude Code CLI with API key support
  - Enhanced ClaudeHelper with installation verification
  - Added configuration settings for Claude CLI sessions
  - Created test script (test-phase-4-1.swift) to verify Claude CLI setup features
  - Enhanced terminal_helper.sh with Claude authentication and initialization functions

### Fixed
- Fixed type casting errors in AgentStatusView by adding dedicated methods for PlanningAgent state handling
- Resolved blank onboarding screens by implementing a more reliable UI approach with direct content rendering
- Fixed non-constant range error in OnboardingView's ForEach loop
- Eliminated XCTest framework dependencies that caused linker errors in demonstration app
- Enhanced UI components with proper initialization and state management
- Added missing authentication and initialization functions to handle_claude in terminal_helper.sh
- Improved Claude CLI session status tracking with proper state management
- Added proper error handling for Claude CLI operations
- Fixed build errors in RealtimeSession.swift related to assistant message handling

## [0.8.0] - 2025-03-09

### Added
- Completed Phase 3.2: Plan Management Features
- Enhanced PlanningAgent with version control capabilities via PlanVersion structure
- Added history tracking for plan items with HistoryEntry structure
- Implemented functions for creating, loading, and deleting plan versions
- Enhanced reporting with functions for priority and status-based reports
- Added detailed plan item management with dependencies, tags, and priorities
- Updated AgentMessage to include new plan management message types
- Implemented FilePlanStorage for persistent storage of plan data
- Added test script for verifying Phase 3.2 implementation
- Added convenience functions for safety versions and demo versions

### Fixed
- Resolved build errors related to missing type definitions
- Fixed incomplete implementation of PlanStorageProtocol
- Added missing helper functions for extracting plan information
- Enhanced code organization with proper documentation
- Improved error handling in plan data loading and saving
- Fixed duplicate function declarations in PlanningAgent class
- Added @discardableResult attributes to prevent unused result warnings
- Implemented missing extractPriority and extractTags functions
- Corrected message type enum references in handler functions

## [0.7.5] - 2025-03-09

### Added
- Completed Phase 3.1: Plan Storage and Backup Functionality
- Implemented PlanStorageProtocol for standardized plan data management
- Created FilePlanStorage implementation for file-based persistence
- Added PlanBackupInfo structure for tracking backups
- Enhanced PlanningAgent with backup and recovery capabilities
- Added methods for creating, restoring, and deleting backups
- Improved plan item structure with priorities, tags, and dependencies
- Enhanced plan item helper methods for status updates and dependency management
- Implemented better plan formatting and user input processing
- Added error handling for storage operations

### Fixed
- Improved error handling for file operations
- Enhanced data persistence reliability
- Fixed issues with plan data serialization and deserialization

## [0.7.0] - 2025-03-09

### Added
- Completed Phase 2.2: Voice Processing Implementation
- Implemented VoiceProcessor using macOS Speech Recognition framework
- Added voice activity detection for determining when user is speaking
- Integrated text-to-speech capabilities for AI responses
- Updated RealtimeSession to process transcribed text instead of raw audio
- Modified ConversationAgent to handle voice command processing
- Implemented AgentMessage model updates for voice-related message types

### Fixed
- Resolved warning in RealtimeSession.swift related to nil coalescing operator on non-optional value
- Fixed unreachable catch block in ConversationAgent.swift
- Removed redundant type casting in VoiceProcessor.swift
- Eliminated unused variable declaration in VoiceProcessor.swift
- Updated code to follow Swift best practices and resolved compiler warnings

## [0.6.0] - 2025-03-08

### Added
- Completed Phase 2.1: Realtime API Integration
- WebSocket connection to OpenAI Realtime API with proper authentication
- Event handling for session events, text deltas, and audio deltas
- Function calling capability for terminal command execution
- Message handling and state management for the Realtime session
- Audio input/output streaming support

### Fixed
- Addressed compiler warnings related to Sendable protocol conformance
- Fixed WebSocket connection handling in RealtimeSession model
- Corrected async/await usage in WebSocket connection process
- Updated deprecated API calls in TerminalController
- Improved error handling in WebSocket message processing
- Enhanced RealtimeSession model with proper error recovery
- Implemented safer memory management with weak self references

## [0.5.0] - 2025-03-07

### Fixed
- Properly integrated Swift Package dependencies (WebSocketKit, NIO, AsyncHTTPClient)
- Fixed missing module errors for package dependencies
- Configured proper package linkage for the project target
- Enhanced RealtimeSession model to use Swift packages

### Changed
- Updated package management to use Xcode's native package system
- Improved project structure for better package integration

## [0.4.5] - 2025-03-07

### Added
- AI Agent Models implementation (Phase 1.3)
- AgentMessage model for structured agent communication
- RealtimeSession model for OpenAI Realtime API integration
- ConversationAgent model for user interaction and workflow orchestration
- PlanningAgent model for project context and memory
- test-phase-1-3.swift to verify implementation

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
