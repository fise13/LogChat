//
//  SearchResultsCardView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct SearchResultsCardView: View {
    let results: [SearchResult]
    let onSourceTap: (URL) -> Void
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .foregroundColor(DesignSystem.Accent.primary)
                        .font(.system(size: 18))
                    
                    Text("Found \(results.count) source\(results.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            
            // Results list
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(results.prefix(5)) { result in
                        SearchResultRow(result: result, onTap: onSourceTap)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Background.secondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Accent.primary.opacity(0.2), lineWidth: 1)
        )
        .shadow(DesignSystem.Shadow.small)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let onTap: (URL) -> Void
    
    var body: some View {
        Button {
            if let url = URL(string: result.url) {
                onTap(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Title
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .foregroundColor(DesignSystem.Accent.primary)
                        .font(.system(size: 14))
                    
                    Text(result.title)
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                // Snippet
                if !result.snippet.isEmpty {
                    Text(result.snippet)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // URL
                HStack(spacing: 4) {
                    Text(result.url)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Accent.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(DesignSystem.Accent.primary)
                        .font(.system(size: 12))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(DesignSystem.Background.tertiary)
            .cornerRadius(DesignSystem.CornerRadius.small)
        }
        .buttonStyle(.plain)
    }
}
