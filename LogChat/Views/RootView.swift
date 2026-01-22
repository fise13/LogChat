//
//  RootView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif
struct RootView: View {
    @State private var selectedTab = 0
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    @AppStorage("onboardingCompleted") private var onboardingCompleted: Bool = false
    @State private var isUnlocked: Bool = false
    @State private var showOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        ZStack {
            if biometricEnabled && !isUnlocked {
                LockScreenView(isUnlocked: $isUnlocked)
                    .transition(.opacity)
            } else if !onboardingCompleted {
                OnboardingView()
                    .transition(.opacity)
                    .onAppear {
                        showOnboarding = true
                    }
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .onChange(of: biometricEnabled) { _, enabled in
            if !enabled {
                isUnlocked = true
            } else if enabled && !isUnlocked {
                isUnlocked = false
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Блокируем при переходе в фон, если биометрия включена
            if biometricEnabled {
                isUnlocked = false
            }
        }
        #endif
    }
    
    private var mainContent: some View {
        ZStack {
            DesignSystem.Background.primary
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)
                
                NavigationStack {
                    ChatView(chat: nil)
                }
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(1)
                
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.fill")
                    }
                    .tag(2)
                
                StatisticsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    .tag(3)
                
                NotesView()
                    .tabItem {
                        Label("Notes", systemImage: "note.text")
                    }
                    .tag(4)
                
                FocusSessionView()
                    .tabItem {
                        Label("Focus", systemImage: "timer")
                    }
                    .tag(5)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(6)
            }
            .tint(DesignSystem.Accent.primary)
        }
        .task {
            // Initial sync on app launch - синхронизируем все данные из Firebase
            if firebaseService.isFirebaseAvailable {
                await firebaseService.syncAll(context: modelContext)
            }
            
            // Perform memory maintenance on app launch
            MemoryService.shared.performMemoryMaintenance(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ChatSaved"))) { _ in
            // Автоматическая синхронизация при сохранении чата
            if firebaseService.isFirebaseAvailable {
                Task {
                    try? await firebaseService.syncChats(context: modelContext)
                }
            }
        }
    }
}
