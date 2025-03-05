//
//  TerminalView.swift
//  SpeechToCode
//
//  Created by Chris Beavis on 04/03/2025.
//

import SwiftUI

struct TerminalView: View {
    @StateObject private var terminalController = TerminalController()
    @State private var commandInput: String = ""
    @State private var showSummary: Bool = false
    @State private var autoScroll: Bool = true
    @State private var commonCommands = [
        "ls -la",
        "pwd",
        "echo $PATH",
        "ps aux",
        "top -l 1"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal header with controls
            HStack {
                Text("Terminal Controller")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    autoScroll.toggle()
                }) {
                    Label(autoScroll ? "Auto-scroll ON" : "Auto-scroll OFF", 
                          systemImage: autoScroll ? "text.append" : "text.badge.xmark")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    showSummary.toggle()
                }) {
                    Label(showSummary ? "Hide Summary" : "Show Summary", 
                          systemImage: showSummary ? "eye.slash" : "eye")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(terminalController.terminalOutput, forType: .string)
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    terminalController.terminalOutput = ""
                }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            
            // Terminal output display
            ScrollViewReader { scrollView in
                ScrollView {
                    Text(terminalController.terminalOutput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black)
                        .foregroundColor(.green)
                        .id("outputEnd")
                        .onChange(of: terminalController.terminalOutput) { _, _ in
                            if autoScroll {
                                scrollView.scrollTo("outputEnd", anchor: .bottom)
                            }
                        }
                }
                .frame(maxHeight: showSummary ? 250 : 350)
            }
            
            // Interactive prompt controls (shown only when in interactive mode)
            if terminalController.isInteractiveMode {
                VStack(spacing: 10) {
                    Text("Interactive Prompt Detected")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            terminalController.sendYes()
                        }) {
                            Text("Yes (y)")
                                .frame(minWidth: 80)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(5)
                        }
                        
                        Button(action: {
                            terminalController.sendNo()
                        }) {
                            Text("No (n)")
                                .frame(minWidth: 80)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(5)
                        }
                        
                        Button(action: {
                            terminalController.sendEnter()
                        }) {
                            Text("Enter ↵")
                                .frame(minWidth: 80)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(5)
                        }
                    }
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            terminalController.sendUp()
                        }) {
                            Image(systemName: "arrow.up")
                                .frame(minWidth: 40)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5)
                        }
                        
                        Button(action: {
                            terminalController.sendDown()
                        }) {
                            Image(systemName: "arrow.down")
                                .frame(minWidth: 40)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5)
                        }
                        
                        Button(action: {
                            terminalController.sendEscape()
                        }) {
                            Text("Esc")
                                .frame(minWidth: 40)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5)
                        }
                        
                        // Custom keystroke input
                        TextField("Custom key", text: $commandInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                        
                        Button(action: {
                            if !commandInput.isEmpty {
                                terminalController.sendKeystroke(commandInput)
                                commandInput = ""
                            }
                        }) {
                            Text("Send Key")
                                .frame(minWidth: 80)
                                .padding(.vertical, 5)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(5)
                        }
                        .disabled(commandInput.isEmpty)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            
            // Summary section
            if showSummary {
                VStack(alignment: .leading) {
                    Text("Summary")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        Text(terminalController.summary)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .frame(height: 100)
                }
                .padding(.horizontal)
            }
            
            // Quick commands section
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(commonCommands, id: \.self) { command in
                        Button(action: {
                            terminalController.sendCommand(command)
                        }) {
                            Text(command)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Button(action: {
                        // Add a custom command to the list
                        if !commandInput.isEmpty && !commonCommands.contains(commandInput) {
                            commonCommands.append(commandInput)
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .padding(.horizontal, 10)
                    }
                    .disabled(commandInput.isEmpty || commonCommands.contains(commandInput))
                }
                .padding()
            }
            .frame(height: 50)
            
            // Command input
            HStack {
                TextField("Enter command", text: $commandInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !commandInput.isEmpty {
                            terminalController.sendCommand(commandInput)
                            commandInput = ""
                        }
                    }
                
                Button(action: {
                    terminalController.sendCommand(commandInput)
                    commandInput = ""
                }) {
                    Text("Send")
                }
                .disabled(commandInput.isEmpty)
            }
            .padding()
            
            // Terminal control buttons
            HStack {
                Button(action: {
                    if terminalController.isConnected {
                        terminalController.disconnectFromTerminal()
                    } else {
                        terminalController.connectToTerminal()
                    }
                }) {
                    HStack {
                        Image(systemName: terminalController.isConnected ? "stop.circle" : "play.circle")
                        Text(terminalController.isConnected ? "Disconnect" : "Connect to Terminal")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(terminalController.isConnected ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Open Terminal button
                Button(action: {
                    terminalController.openTerminal()
                }) {
                    HStack {
                        Image(systemName: "terminal")
                        Text("Open Terminal")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            // Connect to Terminal when view appears
            terminalController.connectToTerminal()
        }
        .onDisappear {
            // Clean up when view disappears
            terminalController.disconnectFromTerminal()
        }
    }
}

#Preview {
    TerminalView()
}
