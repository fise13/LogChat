//
//  WebSearchIndicatorView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct WebSearchIndicatorView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated search icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Accent.primary.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Accent.primary)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Searching the web...")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Finding up-to-date information")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ProgressView()
                .scaleEffect(0.8)
                .tint(DesignSystem.Accent.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Accent.primary.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(DesignSystem.Shadow.small)
        .onAppear {
            // Упрощенная анимация для лучшей производительности
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
