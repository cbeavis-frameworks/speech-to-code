//
//  InstallationProgressView.swift
//  SpeechToCode
//
//  Created on: 2025-03-03
//

import SwiftUI

/// A view component that displays installation progress
struct InstallationProgressView: View {
    let progress: Double
    let message: String
    let error: String?
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(height: 8)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text(message)
                .font(.headline)
            
            if let error = error, !error.isEmpty {
                // Error message is hidden
            }
        }
        .padding()
        .frame(maxWidth: 500)
    }
}
