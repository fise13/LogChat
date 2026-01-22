//
//  FocusSessionView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData
import Combine
#if os(iOS)
import UIKit
#endif

struct FocusSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var timer = FocusTimer()
    @State private var selectedDuration: TimeInterval = 1500 // 25 минут
    @State private var selectedMode: AIMode = .coding
    @State private var currentSession: FocusSession?
    @State private var showingSessionComplete = false
    
    private let durations: [(label: String, seconds: TimeInterval)] = [
        ("15 мин", 900),
        ("25 мин", 1500),
        ("45 мин", 2700),
        ("60 мин", 3600)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                if timer.isRunning {
                    ActiveSessionView(
                        timer: timer,
                        mode: selectedMode,
                        onComplete: {
                            completeSession()
                        },
                        onCancel: {
                            cancelSession()
                        }
                    )
                } else {
                    InactiveSessionView(
                        selectedDuration: $selectedDuration,
                        selectedMode: $selectedMode,
                        durations: durations,
                        onStart: {
                            startSession()
                        }
                    )
                }
            }
            .navigationTitle("Focus Session")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NeoChatLogoView(size: .small, showText: false)
                }
            }
            .alert("Сессия завершена!", isPresented: $showingSessionComplete) {
                Button("Отлично!") { }
            } message: {
                Text("Вы успешно завершили \(Int(selectedDuration / 60)) минут фокуса")
            }
        }
    }
    
    private func startSession() {
        let session = FocusSession(
            duration: selectedDuration,
            mode: selectedMode
        )
        modelContext.insert(session)
        currentSession = session
        
        timer.start(duration: selectedDuration)
        
        do {
            try modelContext.save()
        } catch {
            print("Error starting session: \(error)")
        }
    }
    
    private func completeSession() {
        timer.stop()
        
        if let session = currentSession {
            session.endTime = Date()
            session.isCompleted = true
            
            do {
                try modelContext.save()
            } catch {
                print("Error completing session: \(error)")
            }
        }
        
        showingSessionComplete = true
        currentSession = nil
    }
    
    private func cancelSession() {
        timer.stop()
        
        if let session = currentSession {
            modelContext.delete(session)
            
            do {
                try modelContext.save()
            } catch {
                print("Error canceling session: \(error)")
            }
        }
        
        currentSession = nil
    }
}

struct InactiveSessionView: View {
    @Binding var selectedDuration: TimeInterval
    @Binding var selectedMode: AIMode
    let durations: [(label: String, seconds: TimeInterval)]
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Режим работы
            VStack(spacing: 16) {
                Text("Режим работы")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ForEach(AIMode.allCases) { mode in
                        ModeSelectionCard(
                            mode: mode,
                            isSelected: selectedMode == mode
                        ) {
                            selectedMode = mode
                        }
                    }
                }
            }
            
            // Длительность
            VStack(spacing: 16) {
                Text("Длительность")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ForEach(durations, id: \.seconds) { duration in
                        DurationCard(
                            label: duration.label,
                            isSelected: selectedDuration == duration.seconds
                        ) {
                            selectedDuration = duration.seconds
                        }
                    }
                }
            }
            
            Spacer()
            
            // Кнопка старта
            Button(action: onStart) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Начать сессию")
                        .font(DesignSystem.Typography.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
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
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .padding(DesignSystem.Spacing.md)
    }
}

struct ModeSelectionCard: View {
    let mode: AIMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? mode.color : mode.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : mode.color)
                }
                
                Text(mode.displayName)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? mode.color.opacity(0.1) : DesignSystem.Background.secondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? mode.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DurationCard: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isSelected ? DesignSystem.Accent.primary : DesignSystem.Background.secondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : DesignSystem.Accent.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ActiveSessionView: View {
    @ObservedObject var timer: FocusTimer
    let mode: AIMode
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Таймер
            ZStack {
                Circle()
                    .stroke(DesignSystem.Background.secondary, lineWidth: 12)
                    .frame(width: 220, height: 220)
                
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        LinearGradient(
                            colors: [mode.color, mode.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: timer.progress)
                
                VStack(spacing: 8) {
                    Text(timer.timeString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(mode.displayName)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Кнопки управления
            HStack(spacing: 20) {
                Button(action: onCancel) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Отмена")
                    }
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: onComplete) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Завершить")
                    }
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(mode.color)
                    .cornerRadius(12)
                }
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

class FocusTimer: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var isRunning: Bool = false
    
    private var timer: Timer?
    private var totalDuration: TimeInterval = 0
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalDuration)
    }
    
    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func start(duration: TimeInterval) {
        totalDuration = duration
        timeRemaining = duration
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stop()
                // Можно добавить звуковое уведомление
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
}

