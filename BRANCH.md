# Current Development Branch

The SpeechToCode project is currently being developed on the following branch:

**Branch name:** `feature/claude-code-cli`

## Branch Purpose

This branch focuses on implementing integration with the Claude Code CLI to enable voice-to-code functionality:

1. Creating a ClaudeCodeService to interface with the CLI
2. Implementing voice command processing and parsing
3. Setting up project context management for accurate code generation
4. Adding error handling and retries for CLI interactions
5. Creating a user-friendly UI for voice interaction 

## Pending Work

Before merging this branch back to main, the following items should be completed:

1. ⬜ Create ClaudeCodeService for interacting with Claude Code CLI
2. ⬜ Implement voice command processing pipeline
3. ⬜ Create project context management system
4. ⬜ Add error handling for CLI communication failures
5. ⬜ Develop voice control UI components
6. ⬜ Write comprehensive tests for the service

## How to Use

To check out this branch:

```bash
git checkout feature/claude-code-cli
```

To merge this branch to main once all tests pass:

```bash
git checkout main
git merge feature/claude-code-cli
git push
