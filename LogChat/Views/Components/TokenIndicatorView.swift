//
//  TokenIndicatorView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct TokenIndicatorView: View {
    let tokenCount: Int
    let limit: Int
    let tokensPerSecond: Double?
    
    var progress: Double {
        min(1.0, Double(tokenCount) / Double(limit))
    }
    
    var isNearLimit: Bool {
        progress > 0.8
    }
    
    var progressColor: Color {
        if progress > 0.9 {
            return DesignSystem.Accent.danger
        } else if progress > 0.7 {
            return DesignSystem.Accent.warning
        } else {
            return DesignSystem.Accent.primary
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("\(tokenCount) / \(limit) tokens", systemImage: "number.circle.fill")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let tps = tokensPerSecond, tps > 0 {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.secondary)
                        Text("\(String(format: "%.1f", tps)) tok/s")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignSystem.Background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isNearLimit ? progressColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}
