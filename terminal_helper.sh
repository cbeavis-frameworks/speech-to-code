#!/bin/bash

# Terminal Helper Script for SpeechToCode
# This script helps the SpeechToCode app interact with Terminal.app

# Function to send a command to Terminal.app using keystroke simulation
# This is more reliable for interactive prompts than do script
send_command() {
    local command="$1"
    
    # Send the command as keystrokes and then press return
    osascript <<EOF
    tell application "Terminal" to activate
    delay 0.3
    tell application "System Events" to tell process "Terminal"
        keystroke "$command"
        delay 0.2
        key code 36  # Return key
    end tell
EOF
}

# Function to send a Claude-specific command to Terminal.app
# This handles the special formatting and options for Claude CLI
claude_command() {
    local command="$1"
    local options="$2"
    
    # If options are provided, include them
    if [ -n "$options" ]; then
        send_command "claude $options \"$command\""
    else
        send_command "claude \"$command\""
    fi
}

# Function to send a specific keystroke to Terminal.app
send_keystroke() {
    local key="$1"
    
    # Map common key names to their key codes
    case "$key" in
        "enter"|"return")
            key_code="36"
            ;;
        "up")
            key_code="126"
            ;;
        "down")
            key_code="125"
            ;;
        "esc"|"escape")
            key_code="53"
            ;;
        "y")
            # For "y" we'll send the letter and then return
            osascript <<EOF
            tell application "Terminal" to activate
            delay 0.2
            tell application "System Events" to tell process "Terminal"
                keystroke "y"
                delay 0.1
                key code 36
            end tell
EOF
            return
            ;;
        "n")
            # For "n" we'll send the letter and then return
            osascript <<EOF
            tell application "Terminal" to activate
            delay 0.2
            tell application "System Events" to tell process "Terminal"
                keystroke "n"
                delay 0.1
                key code 36
            end tell
EOF
            return
            ;;
        *)
            # If it's not a special key, treat it as a character to type
            osascript <<EOF
            tell application "Terminal" to activate
            delay 0.2
            tell application "System Events" to tell process "Terminal"
                keystroke "$key"
            end tell
EOF
            return
            ;;
    esac
    
    # Send the key code
    osascript <<EOF
    tell application "Terminal" to activate
    delay 0.2
    tell application "System Events" to tell process "Terminal"
        key code $key_code
    end tell
EOF
}

# Function to read the current content of Terminal.app
read_terminal_content() {
    osascript <<EOF
    tell application "Terminal"
        if not (exists window 1) then
            return "No Terminal window is open."
        end if
        set currentTab to selected tab of window 1
        set terminalContent to contents of currentTab
        return terminalContent
    end tell
EOF
}

# Function to detect if Terminal is showing a Claude CLI prompt
detect_claude_prompt() {
    local terminal_content=$(read_terminal_content)
    
    # Check for common Claude CLI prompt patterns
    if echo "$terminal_content" | grep -q -E '(Claude Code|>|/bug|/clear|/compact|/config|/cost|/doctor|/help|/init|/login|/logout|/pr_comments|/review|/terminal-setup)'; then
        echo "claude_prompt_detected"
    else
        echo "no_claude_prompt"
    fi
}

# Function to handle Claude CLI specific interactions
handle_claude() {
    local action="$1"
    shift
    
    case "$action" in
        "init")
            # Initialize Claude CLI in the current directory
            send_command "claude"
            ;;
        "commit")
            # Use Claude to create a commit
            send_command "claude commit"
            ;;
        "slash_command")
            # Send a slash command to Claude
            local slash_cmd="$1"
            send_command "/$slash_cmd"
            ;;
        "interrupt")
            # Interrupt Claude with Ctrl+C
            osascript <<EOF
            tell application "Terminal" to activate
            delay 0.2
            tell application "System Events" to tell process "Terminal"
                key code 0 using control down  # Ctrl+A (ASCII code 0 is 'a')
            end tell
EOF
            ;;
        *)
            echo "Unknown Claude action: $action"
            ;;
    esac
}

# Function to check if Terminal.app is running
is_terminal_running() {
    local running=$(osascript <<EOF
    tell application "System Events"
        return (exists process "Terminal")
    end tell
EOF
    )
    
    echo "$running"
}

# Main function to handle different commands
main() {
    local action="$1"
    shift
    
    case "$action" in
        "send_command")
            send_command "$@"
            ;;
        "claude_command")
            claude_command "$@"
            ;;
        "send_keystroke")
            send_keystroke "$@"
            ;;
        "read_content")
            read_terminal_content
            ;;
        "is_running")
            is_terminal_running
            ;;
        "detect_claude_prompt")
            detect_claude_prompt
            ;;
        "handle_claude")
            handle_claude "$@"
            ;;
        *)
            echo "Unknown action: $action"
            echo "Usage: $0 [send_command|claude_command|send_keystroke|read_content|is_running|detect_claude_prompt|handle_claude] [arguments]"
            exit 1
            ;;
    esac
}

# Execute the main function with all arguments
main "$@"
