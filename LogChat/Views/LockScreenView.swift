//
//  LockScreenView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @Binding var isUnlocked: Bool
    @State private var isAnimating = false
    @State private var authenticationError: String?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient(
                colors: [
                    DesignSystem.Accent.primary.opacity(0.1),
                    DesignSystem.Background.primary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Логотип с анимацией
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
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .semibold))
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
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 20)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                
                VStack(spacing: 12) {
                    Text("NeoChat")
                        .font(DesignSystem.Typography.largeTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .primary,
                                    DesignSystem.Accent.primary
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Защищено биометрией")
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Кнопка аутентификации
                Button(action: authenticate) {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.system(size: 24, weight: .medium))
                        Text("Разблокировать")
                            .font(DesignSystem.Typography.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignSystem.Accent.primary,
                                DesignSystem.Accent.primary.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: DesignSystem.Accent.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                
                if showError, let error = authenticationError {
                    Text(error)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Accent.danger)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Accent.danger.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
            // Автоматическая аутентификация при появлении
            authenticate()
        }
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Если биометрия недоступна, разблокируем
            if error?.code == LAError.biometryNotAvailable.rawValue {
                isUnlocked = true
            } else {
                authenticationError = "Биометрия недоступна"
                showError = true
            }
            return
        }
        
        let reason = "Подтвердите вашу личность для доступа к NeoChat"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isUnlocked = true
                    }
                } else {
                    if let error = error as? LAError {
                        switch error.code {
                        case .userCancel:
                            authenticationError = "Аутентификация отменена"
                        case .userFallback:
                            authenticationError = "Используйте пароль устройства"
                        default:
                            authenticationError = "Ошибка аутентификации"
                        }
                    } else {
                        authenticationError = "Не удалось аутентифицироваться"
                    }
                    showError = true
                }
            }
        }
    }
}

