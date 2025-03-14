# SpeechToCode - Technical Specification

## Overview
SpeechToCode is a macOS application designed to enable voice-controlled coding and terminal interaction. The application serves as a bridge between natural language input and coding environments, allowing users to control their development workflow through voice commands and AI assistance.

## Core Components

### 1. Terminal Controller
The Terminal Controller provides a bridge between the SpeechToCode app and the macOS Terminal.app, allowing the app to:
- Connect to and control an existing Terminal window
- Send commands to the Terminal
- Read and process Terminal output
- Handle interactive prompts and user choices
- Summarize Terminal activity for easier understanding

#### Key Features:
- **Terminal Connection**: Establishes and maintains a connection to Terminal.app
- **Command Execution**: Sends commands to Terminal with proper keystroke simulation
- **Output Capture**: Continuously polls and captures Terminal output
- **Interactive Mode Detection**: Identifies when Terminal is waiting for user input
- **Keystroke Simulation**: Sends specific keystrokes to respond to prompts (Yes/No/Enter/etc.)
- **Output Summarization**: Condenses Terminal output for easier consumption

### 2. Terminal View
Provides a user interface for interacting with Terminal.app from within the SpeechToCode app:
- Displays Terminal output with auto-scrolling
- Offers command input field for sending commands
- Provides quick-access buttons for common Terminal interactions
- Shows interactive controls when Terminal is in interactive mode
- Displays summarized Terminal activity

### 3. Multi-Agent Architecture
SpeechToCode implements a multi-agent architecture to provide a seamless voice-controlled coding experience:

#### 3.1 Conversation Agent
- Handles user interaction and orchestrates workflow
- Processes voice commands and generates responses
- Communicates with the Terminal Controller to execute commands
- Manages communication with the Planning Agent

#### 3.2 Planning Agent
- Maintains project context and long-term memory
- Tracks tasks and project status
- Provides context for the Conversation Agent
- Helps with decision making for complex operations

##### 3.2.1 Plan Management Features
- **Plan Creation and Initialization**: Creates and initializes project plans with task items
- **Task Tracking**: Manages task status, priorities, and dependencies
- **Plan Versioning**: Saves, loads, and manages different versions of project plans
- **History Tracking**: Records and retrieves history of changes to plan items
- **Advanced Reporting**: Generates summaries and reports based on priorities and status
- **Agent Communication**: Handles plan-related messages between agents
- **Safety Features**: Creates automatic safety backups before significant changes

### 4. API Integrations

#### 4.1 OpenAI Realtime API
- Provides real-time AI processing for voice commands
- Enables function calling for terminal commands
- Processes text-based transcriptions from the macOS Speech Recognition framework
- Handles message streaming and state management

#### 4.2 Anthropic Claude Code CLI
- Provides code-specific AI capabilities
- Integrates with the Terminal Controller for code analysis and generation

#### 4.3 macOS Speech Recognition
- Provides local speech-to-text conversion
- Offers real-time transcription updates
- Enables voice activity detection
- Ensures privacy by processing audio on-device
- Integrates with the application's voice processing pipeline

### 5. Voice Processing
The Voice Processing component uses macOS's native Speech Recognition capabilities to:
- Convert spoken commands to text
- Detect when the user is speaking
- Process voice input in real-time
- Provide text-to-speech for AI responses

#### 5.1 VoiceProcessor
- Manages audio recording sessions
- Processes audio input via macOS Speech Recognition
- Detects voice activity
- Provides transcription updates
- Handles text-to-speech conversion

#### 5.2 Integration with Agents
- ConversationAgent receives transcribed text from VoiceProcessor
- Processes voice commands using the same pipeline as text input
- Sends responses to VoiceProcessor for text-to-speech when needed
- RealtimeSession processes transcribed text instead of raw audio

### 6. Helper Scripts
- **terminal_helper.sh**: Bash script that handles low-level Terminal interactions using AppleScript
  - Sends commands to Terminal.app
  - Sends keystrokes for interactive prompts
  - Reads Terminal content
  - Checks Terminal status

### 7. Permissions and Security
- Requires Accessibility permissions to control Terminal.app
- Uses AppleScript for Terminal interaction
- Includes proper entitlements for automation
- Securely manages API keys for OpenAI and Anthropic

## Dependencies
SpeechToCode relies on several Swift packages to provide the necessary functionality:

### Network & Real-time Communication 
- **WebSocketKit** - Provides WebSocket communication for real-time interaction with the OpenAI API
- **NIO** - Swift NIO framework for asynchronous networking
- **AsyncHTTPClient** - Asynchronous HTTP client for Swift
- **NIOFoundationCompat** - NIO integration with Foundation
- **NIOConcurrencyHelpers** - Concurrency utilities for NIO
- **NIOCore** - Core components of Swift NIO
- **NIOEmbedded** - Embedded test utilities for NIO

These dependencies are integrated directly into the Xcode project using Xcode's built-in package management system.

## Technical Implementation

### Terminal Interaction Flow
1. User inputs a command via SpeechToCode interface
2. TerminalController processes the command
3. terminal_helper.sh sends the command to Terminal.app using keystroke simulation
4. TerminalController polls Terminal output to capture the result
5. Output is displayed and optionally summarized in the TerminalView

### Interactive Prompt Handling
1. TerminalController detects patterns indicating an interactive prompt
2. TerminalView displays appropriate interactive controls
3. User selects a response (or AI agent determines appropriate response)
4. TerminalController sends the corresponding keystroke to Terminal.app

### Multi-Agent Communication Flow
1. User speaks a command → Speech recognition converts to text
2. Text sent to Conversation Agent via Realtime API
3. Conversation Agent processes request and may:
   - Query Planning Agent for context
   - Issue terminal commands via function calling
   - Generate direct responses to the user
4. Terminal Controller executes commands in Terminal (with Claude Code)
5. Terminal output is captured and returned to Conversation Agent
6. Conversation Agent decides next steps based on terminal output and plan
7. Agent provides voice and visual feedback to the user

### AI Integration Points
- Terminal output analysis for context understanding
- Interactive prompt detection and option extraction
- Decision making for automated responses to prompts
- Command generation based on natural language input
- Project context management and task tracking

## Implementation Status

### Completed Components
- **Terminal Controller**: Basic implementation for controlling Terminal.app
- **Terminal View**: User interface for terminal interaction
- **Project Configuration**: API dependencies, keys, and permissions (March 6, 2025)
- **Terminal Controller Enhancements for Claude Code CLI** (March 6, 2025)
- **AI Agent Models**: Implementation of RealtimeSession, ConversationAgent, PlanningAgent, and AgentMessage models (March 7, 2025)
- **Realtime API Integration**: Implementation of WebSocket connection to OpenAI Realtime API with message handling and function calling (March 8, 2025)
- **Voice Processing**: Implementation of VoiceProcessor for speech recognition and transcription processing (March 8, 2025)
- **Plan Storage**: Implementation of PlanStorage for persistent storage of plan data, including backup and recovery mechanisms (March 9, 2025)
- **Context Management**: Implementation of ContextManager for shared context between agents (March 10, 2025)
- **Workflow Automation**: Implementation of WorkflowManager for managing automated workflows and task execution sequences (March 10, 2025)

### In Progress
- User Experience Refinement

## Future Enhancements
1. **Enhanced Pattern Recognition**: Improve detection of various terminal prompts
2. **AI Decision Making**: Implement AI-based decision making for terminal interactions
3. **Context-Aware Suggestions**: Provide intelligent suggestions based on terminal history
4. **Custom Terminal Profiles**: Support for different terminal configurations
5. **Multi-Window Support**: Control multiple terminal windows simultaneously
6. **Voice Output**: Text-to-speech for agent responses

## Technical Requirements
- macOS 14.0 or later
- Swift 5.9+
- Terminal.app accessibility permissions
- AppleScript automation permissions
- OpenAI API key
- Anthropic API key
