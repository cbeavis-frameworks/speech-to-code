# SpeechToCode

A macOS application that enables voice-controlled coding and terminal interaction, bridging natural language input with development environments.

## Features

- **Terminal Control**: Interact with Terminal.app directly from the application
- **Command Execution**: Send commands to Terminal with proper keystroke simulation
- **Interactive Prompt Handling**: Detect and respond to Terminal prompts (yes/no questions, selections)
- **Terminal Output Capture**: View Terminal output within the application
- **Output Summarization**: Get concise summaries of Terminal activity

## Requirements

- macOS 11.0 or later
- Xcode 12.0 or later (for development)
- Terminal.app

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/SpeechToCode.git
   ```

2. Open the project in Xcode:
   ```
   cd SpeechToCode
   open SpeechToCode.xcodeproj
   ```

3. Build and run the application from Xcode, or use the provided script:
   ```
   ./build_and_run.sh
   ```

## Permissions

SpeechToCode requires the following permissions:

- **Accessibility**: To control Terminal.app with keystrokes
- **Apple Events**: To interact with Terminal.app using AppleScript

These permissions can be granted in System Preferences > Security & Privacy > Privacy.

## Usage

1. Launch the application
2. Navigate to the Terminal tab
3. Click "Open Terminal" to connect to Terminal.app
4. Use the command input field to send commands to Terminal
5. For interactive prompts, use the provided buttons (Yes, No, Enter) or custom keystroke field

## Project Structure

- **SpeechToCode/**: Main application code
  - **TerminalController.swift**: Core logic for Terminal interaction
  - **TerminalView.swift**: UI for Terminal interaction
  - **ContentView.swift**: Main application view
- **terminal_helper.sh**: Helper script for Terminal interaction
- **build_and_run.sh**: Script to build and run the application
- **test_terminal.sh**: Test script for verifying Terminal interaction

## Development

### Building from Source

1. Ensure Xcode is installed
2. Open SpeechToCode.xcodeproj
3. Select your target device
4. Build and run (⌘+R)

### Testing Terminal Interaction

Use the provided test script to verify Terminal interaction capabilities:

```
./test_terminal.sh
```

This script will prompt for various inputs to test the application's ability to handle interactive Terminal sessions.

## License

[MIT License](LICENSE)

## Acknowledgements

- Apple's SwiftUI framework
- AppleScript for Terminal automation
