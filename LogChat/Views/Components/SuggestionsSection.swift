//
//  SuggestionsSection.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct SuggestionsSection: View {
    let suggestions: [Suggestion]
    let onSuggestionTap: (Suggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Контекстные подсказки")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Accent.primary.opacity(0.6))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion) {
                            onSuggestionTap(suggestion)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: Suggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(suggestion.mode.color.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: suggestion.mode.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(suggestion.mode.color)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignSystem.Accent.primary.opacity(0.6))
                }
                
                Text(suggestion.title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if case .continueChat(let chat) = suggestion {
                    if let lastMessage = chat.messages?.sorted(by: { $0.timestamp < $1.timestamp }).last {
                        Text(lastMessage.content.prefix(50) + (lastMessage.content.count > 50 ? "..." : ""))
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text(suggestion.prompt)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(width: 200)
            .background(DesignSystem.Background.secondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(suggestion.mode.color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

