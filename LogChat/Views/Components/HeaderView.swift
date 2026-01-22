//
//  HeaderView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct HeaderView: View {
    let currentMode: AIMode
    @Binding var selectedMode: AIMode
    var onNewChat: (() -> Void)? = nil
    @State private var showModePicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo
            NeoChatLogoView(size: .medium)
            
            Spacer()
            
            // Mode Selector Button
            Button(action: {
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.light)
                generator.impactOccurred()
                #endif
                showModePicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: currentMode.icon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(currentMode.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(DesignSystem.Accent.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    DesignSystem.Accent.primary.opacity(0.1)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(DesignSystem.Accent.primary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .confirmationDialog("Select AI Mode", isPresented: $showModePicker, titleVisibility: .visible) {
                ForEach(AIMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.displayName)
                            if mode == currentMode {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            // New Chat Button
            Button(action: {
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.light)
                generator.impactOccurred()
                #endif
                onNewChat?()
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Accent.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        DesignSystem.Accent.primary.opacity(0.1)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(DesignSystem.Accent.primary.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            DesignSystem.Background.primary
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}
