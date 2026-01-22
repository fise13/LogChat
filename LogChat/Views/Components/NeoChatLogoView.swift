//
//  NeoChatLogoView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct NeoChatLogoView: View {
    var size: LogoSize = .medium
    var showText: Bool = true
    @State private var isAnimating = false
    
    enum LogoSize {
        case small
        case medium
        case large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 28
            }
        }
        
        var textSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 24
            }
        }
        
        var spacing: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }
    
    var body: some View {
        HStack(spacing: size.spacing) {
            // Логотип - комбинация иконок с градиентом
            ZStack {
                // Фоновый круг с градиентом
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Accent.primary.opacity(0.2),
                                DesignSystem.Accent.primary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.iconSize * 1.8, height: size.iconSize * 1.8)
                
                // Основная иконка sparkles
                Image(systemName: "sparkles")
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Accent.primary,
                                DesignSystem.Accent.primary.opacity(0.7),
                                Color.blue.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 20)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                // Дополнительные маленькие sparkles для эффекта
                ForEach(0..<3) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: size.iconSize * 0.4, weight: .medium))
                        .foregroundColor(DesignSystem.Accent.primary.opacity(0.6))
                        .offset(
                            x: cos(Double(index) * 2 * .pi / 3) * size.iconSize * 0.6,
                            y: sin(Double(index) * 2 * .pi / 3) * size.iconSize * 0.6
                        )
                        .opacity(isAnimating ? 0.8 : 0.4)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
            // Текст логотипа
            if showText {
                Text("NeoChat")
                    .font(.system(size: size.textSize, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .primary,
                                DesignSystem.Accent.primary.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Упрощенная версия для использования в маленьких местах
struct NeoChatIconView: View {
    var size: CGFloat = 24
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Accent.primary.opacity(0.2),
                            DesignSystem.Accent.primary.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignSystem.Accent.primary,
                            DesignSystem.Accent.primary.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        NeoChatLogoView(size: .small)
        NeoChatLogoView(size: .medium)
        NeoChatLogoView(size: .large)
        NeoChatLogoView(size: .medium, showText: false)
        NeoChatIconView(size: 32)
    }
    .padding()
}

