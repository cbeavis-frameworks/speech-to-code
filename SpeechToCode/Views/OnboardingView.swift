import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var preferences: UserPreferences
    @State private var currentPage = 0
    
    // Hard-coded page definitions for maximum compatibility
    private let pages: [(icon: String, title: String, description: String)] = [
        (icon: "mic.and.signal.meter", title: "Welcome to SpeechToCode", description: "Transform the way you code with voice commands and AI assistance. This quick tutorial will show you the basics."),
        (icon: "terminal", title: "Terminal Control", description: "Control your Terminal with voice commands. Say commands like \"Run git status\" or \"List files in directory\" to execute them without typing."),
        (icon: "waveform", title: "Voice Commands", description: "Use natural language to write and edit code. Say commands like \"Create a function that calculates fibonacci numbers\" or \"Fix the bug in this code.\""),
        (icon: "brain", title: "AI Assistants", description: "SpeechToCode uses multiple AI agents to understand your intent and execute complex tasks. The status bar shows you what each agent is doing."),
        (icon: "checkmark.circle", title: "Ready to Start", description: "You're all set! Click the checkmark to start using SpeechToCode. You can always access the help documentation from the toolbar if you need assistance.")
    ]
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Welcome to SpeechToCode")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button("Skip") {
                    preferences.showOnboarding = false
                    dismiss()
                }
            }
            .padding()
            
            Spacer()
            
            // Current page content
            if currentPage >= 0 && currentPage < pages.count {
                let page = pages[currentPage]
                
                VStack(spacing: 20) {
                    Image(systemName: page.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(currentPage == pages.count - 1 ? .green : .blue)
                    
                    Text(page.title)
                        .font(.title)
                        .bold()
                    
                    Text(page.description)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .transition(.opacity)
                .id("page-\(currentPage)") // Force view recreation on page change
            }
            
            Spacer()
            
            // Navigation
            HStack {
                // Back button
                Button(action: {
                    withAnimation {
                        currentPage = max(0, currentPage - 1)
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                }
                .opacity(currentPage > 0 ? 1.0 : 0.0)
                .disabled(currentPage == 0)
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // Next/Finish button
                Button(action: {
                    withAnimation {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        } else {
                            // On the last page, finish onboarding
                            preferences.showOnboarding = false
                            dismiss()
                        }
                    }
                }) {
                    Image(systemName: currentPage < pages.count - 1 ? "chevron.right.circle.fill" : "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom)
        }
        .frame(width: 600, height: 400)
    }
}
