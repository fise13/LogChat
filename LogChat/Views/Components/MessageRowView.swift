//
//  MessageRowView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MessageRowView: View {
    let message: Message
    var onPin: (() -> Void)? = nil
    var onCopy: ((String) -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.role == .assistant {
                // AI message - left side
                VStack(alignment: .leading, spacing: 10) {
                    // Image preview
                    #if os(iOS)
                    if let imageData = message.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .shadow(DesignSystem.Shadow.small)
                            .padding(.bottom, 2)
                    }
                    #endif
                    
                    // Content
                    if !message.content.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            MarkdownContentView(
                                text: message.content,
                                language: message.language,
                                onCopy: { code in
                                    onCopy?(code)
                                }
                            )
                            
                            // Language indicator for assistant messages
                            if let language = message.language,
                               UserDefaults.standard.bool(forKey: "languageAutoDetectEnabled"),
                               !language.isEmpty {
                                LanguageBadge(language: language)
                            }
                            
                            // Sources indicator for messages with web search
                            if let sources = message.searchResults, !sources.isEmpty {
                                MessageSourcesView(
                                    sources: sources,
                                    onSourceTap: { url in
                                        #if os(iOS)
                                        UIApplication.shared.open(url)
                                        #endif
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(DesignSystem.MessageBubble.verticalPadding)
                .padding(.horizontal, DesignSystem.MessageBubble.horizontalPadding)
                .background(DesignSystem.Message.aiBubble)
                .foregroundColor(DesignSystem.Message.aiText)
                #if os(iOS)
                .cornerRadius(DesignSystem.MessageBubble.cornerRadius, corners: [.topLeft, .topRight, .bottomRight])
                #else
                .cornerRadius(DesignSystem.MessageBubble.cornerRadius)
                #endif
                .shadow(DesignSystem.Shadow.small)
                .frame(maxWidth: DesignSystem.MessageBubble.maxWidth, alignment: .leading)
                
                Spacer(minLength: 60)
            } else {
                // User message - right side
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 10) {
                    // Image preview
                    #if os(iOS)
                    if let imageData = message.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                            .shadow(DesignSystem.Shadow.small)
                            .padding(.bottom, 2)
                    }
                    #endif
                    
                    // Content
                    if !message.content.isEmpty {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(message.content)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Message.userText)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Language indicator for user messages
                            if let language = message.language,
                               UserDefaults.standard.bool(forKey: "languageAutoDetectEnabled"),
                               !language.isEmpty {
                                LanguageBadge(language: language)
                            }
                        }
                    }
                }
                .padding(DesignSystem.MessageBubble.verticalPadding)
                .padding(.horizontal, DesignSystem.MessageBubble.horizontalPadding)
                .background(
                    LinearGradient(
                        colors: [
                            DesignSystem.Message.userBubble,
                            DesignSystem.Message.userBubble.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(DesignSystem.Message.userText)
                #if os(iOS)
                .cornerRadius(DesignSystem.MessageBubble.cornerRadius, corners: [.topLeft, .topRight, .bottomLeft])
                #else
                .cornerRadius(DesignSystem.MessageBubble.cornerRadius)
                #endif
                .shadow(DesignSystem.Shadow.medium)
                .frame(maxWidth: DesignSystem.MessageBubble.maxWidth, alignment: .trailing)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, 6)
        .transition(.opacity) // Упрощенная анимация для лучшей производительности
        .contextMenu {
            if let onPin = onPin {
                Button {
                    onPin()
                } label: {
                    Label(
                        message.isPinned ? "Открепить" : "Закрепить",
                        systemImage: message.isPinned ? "pin.slash" : "pin"
                    )
                }
            }
            
            Button {
                onCopy?(message.content)
            } label: {
                Label("Копировать", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Language Badge

struct LanguageBadge: View {
    let language: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "globe")
                .font(.system(size: 9, weight: .medium))
            Text(LanguageDetector.languageDisplayName(language))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MarkdownContentView moved to separate file
