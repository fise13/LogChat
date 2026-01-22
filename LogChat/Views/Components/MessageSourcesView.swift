//
//  MessageSourcesView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct MessageSourcesView: View {
    let sources: [SearchResult]
    let onSourceTap: (URL) -> Void
    @State private var showAllSources: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with badge
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundColor(DesignSystem.Accent.primary)
                    .font(.system(size: 12))
                
                Text("Based on \(sources.count) source\(sources.count == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    withAnimation(DesignSystem.Animation.quick) {
                        showAllSources.toggle()
                    }
                } label: {
                    Text(showAllSources ? "Hide" : "Show")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Accent.primary)
                }
            }
            
            // Sources list
            if showAllSources {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sources.prefix(5)) { source in
                        SourceChip(source: source, onTap: onSourceTap)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Compact view - show first 3 sources as chips
                HStack(spacing: 6) {
                    ForEach(sources.prefix(3)) { source in
                        CompactSourceChip(source: source, onTap: onSourceTap)
                    }
                    
                    if sources.count > 3 {
                        Text("+\(sources.count - 3)")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Background.tertiary)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Source Chip

struct SourceChip: View {
    let source: SearchResult
    let onTap: (URL) -> Void
    
    var body: some View {
        Button {
            if let url = URL(string: source.url) {
                onTap(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 10))
                
                Text(source.title)
                    .font(DesignSystem.Typography.caption)
                    .lineLimit(1)
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10))
            }
            .foregroundColor(DesignSystem.Accent.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignSystem.Accent.primary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Source Chip

struct CompactSourceChip: View {
    let source: SearchResult
    let onTap: (URL) -> Void
    
    var body: some View {
        Button {
            if let url = URL(string: source.url) {
                onTap(url)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 9))
                
                Text(extractDomain(from: source.url))
                    .font(DesignSystem.Typography.caption2)
                    .lineLimit(1)
            }
            .foregroundColor(DesignSystem.Accent.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DesignSystem.Accent.primary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
