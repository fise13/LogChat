//
//  ResearchStatusView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct ResearchStatusView: View {
    let state: ResearchState
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(colorForState(state).opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: state.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorForState(state))
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(state.displayName)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitleForState(state) {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if state == .researching || state == .analyzing || state == .synthesizing {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(colorForState(state))
            } else if state == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Accent.success)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(colorForState(state).opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(DesignSystem.Shadow.small)
        .onAppear {
            // Оптимизированная анимация - реже обновления
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private func colorForState(_ state: ResearchState) -> Color {
        switch state {
        case .analyzing: return DesignSystem.Message.Status.analyzing
        case .clarifying: return DesignSystem.Message.Status.clarifying
        case .researching: return DesignSystem.Message.Status.researching
        case .synthesizing: return DesignSystem.Message.Status.synthesizing
        case .complete: return DesignSystem.Message.Status.complete
        }
    }
    
    private func subtitleForState(_ state: ResearchState) -> String? {
        switch state {
        case .analyzing: return "Изучаю запрос и контекст"
        case .clarifying: return "Нужны дополнительные детали"
        case .researching: return "Ищу актуальную информацию"
        case .synthesizing: return "Формирую финальный ответ"
        case .complete: return "Готово"
        }
    }
}

