//
//  MemorySuggestionView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

#if os(iOS)

struct MemorySuggestionView: View {
    @Binding var suggestions: [MemorySuggestion]
    @Binding var isPresented: Bool
    let onAccept: (MemorySuggestion) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        if !suggestions.isEmpty && isPresented {
            VStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    MemorySuggestionCard(
                        suggestion: suggestion,
                        onAccept: {
                            onAccept(suggestion)
                            suggestions.removeAll { $0.id == suggestion.id }
                            if suggestions.isEmpty {
                                isPresented = false
                            }
                        },
                        onDismiss: {
                            suggestions.removeAll { $0.id == suggestion.id }
                            if suggestions.isEmpty {
                                isPresented = false
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct MemorySuggestionCard: View {
    let suggestion: MemorySuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: suggestion.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Accent.primary)
                    .frame(width: 32, height: 32)
                    .background(DesignSystem.Accent.primary.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Remember this?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        // Importance indicator
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < suggestion.importanceStars ? "star.fill" : "star")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(index < suggestion.importanceStars ? .yellow : .secondary.opacity(0.3))
                            }
                        }
                    }
                    
                    Text(suggestion.displayType)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(suggestion.content)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(isExpanded ? nil : 2)
                
                if let reason = suggestion.reason, !reason.isEmpty {
                    if isExpanded {
                        Text("Why: \(reason)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                if suggestion.reason != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Show less" : "Show more")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Accent.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Not now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Remember")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Accent.primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(DesignSystem.Input.background)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Accent.primary.opacity(0.3), lineWidth: 1.5)
        )
    }
}

#else
// macOS placeholder
struct MemorySuggestionView: View {
    @Binding var suggestions: [MemorySuggestion]
    @Binding var isPresented: Bool
    let onAccept: (MemorySuggestion) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        EmptyView()
    }
}
#endif
