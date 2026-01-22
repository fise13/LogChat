//
//  ChatMessagesListView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ChatMessagesListView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Empty state
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 20) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            DesignSystem.Accent.primary.opacity(0.6),
                                            DesignSystem.Accent.primary.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(spacing: 8) {
                                Text("Start a conversation")
                                    .font(DesignSystem.Typography.title3)
                                    .foregroundColor(.primary)
                                
                                Text("Ask anything or share an image")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xxl)
                    }
                    
                    // Token indicator
                    if viewModel.tokenCount > 0 {
                        TokenIndicatorView(
                            tokenCount: viewModel.tokenCount,
                            limit: TokenService.shared.contextLimit,
                            tokensPerSecond: viewModel.tokensPerSecond
                        )
                        .padding(.top, 12)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                    
                    // Messages - оптимизировано с LazyVStack
                    ForEach(viewModel.messages) { message in
                        MessageRowView(
                            message: message,
                            onPin: {
                                viewModel.togglePinMessage(message)
                            },
                            onCopy: { code in
                                #if os(iOS)
                                UIPasteboard.general.string = code
                                #endif
                            }
                        )
                        .id(message.id)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // Research status indicator
                    if let researchState = viewModel.researchState, viewModel.currentMode == .research {
                        ResearchStatusView(state: researchState)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                    
                    // Web search indicator (for all modes when searching)
                    if viewModel.isSearching {
                        WebSearchIndicatorView()
                            .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                    
                    // Search results card (after search completes)
                    if let searchResults = viewModel.currentSearchResults, !searchResults.isEmpty, !viewModel.isSearching {
                        SearchResultsCardView(
                            results: searchResults,
                            onSourceTap: { url in
                                #if os(iOS)
                                UIApplication.shared.open(url)
                                #endif
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Streaming indicator
                    if viewModel.isStreaming {
                        StreamingIndicatorView(
                            mode: viewModel.currentMode,
                            tokensPerSecond: viewModel.tokensPerSecond,
                            onCancel: {
                                viewModel.cancelStreaming()
                            }
                        )
                    }
                    
                    // Error state
                    if viewModel.hasError, let errorMessage = viewModel.errorMessage {
                        ErrorIndicatorView(
                            message: errorMessage,
                            onDismiss: {
                                viewModel.clearError()
                            }
                        )
                    }
                    
                    // Continue button
                    if viewModel.canContinue && !viewModel.isStreaming {
                        ContinueButtonView {
                            viewModel.continueGeneration()
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToLastMessage(proxy: proxy)
            }
            .onChange(of: viewModel.isStreaming) { _, _ in
                scrollToLastMessage(proxy: proxy)
            }
        }
    }
    
    private func scrollToLastMessage(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

struct StreamingIndicatorView: View {
    let mode: AIMode
    let tokensPerSecond: Double
    let onCancel: () -> Void
    
    private var statusText: String {
        switch mode {
        case .research:
            return "Researching..."
        default:
            return "Thinking..."
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(mode.color)
            
            Text(statusText)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
            
            if tokensPerSecond > 0 {
                Text("• \(String(format: "%.1f", tokensPerSecond)) tok/s")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, 8)
    }
}

struct ErrorIndicatorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DesignSystem.Accent.danger)
                .font(.system(size: 16))
            
            Text(message)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Accent.danger)
                .lineLimit(3)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, 10)
        .background(DesignSystem.Accent.danger.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

struct ContinueButtonView: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Continue")
            }
            .font(DesignSystem.Typography.subheadline)
            .foregroundColor(DesignSystem.Message.userBubble)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Message.userBubble.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

