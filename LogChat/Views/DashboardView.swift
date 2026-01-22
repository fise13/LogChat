//
//  DashboardView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Chat.updatedAt, order: .reverse)]) private var allChats: [Chat]
    
    @State private var selectedQuickAction: QuickAction?
    @State private var selectedSuggestion: Suggestion?
    
    private var recentChats: [Chat] {
        Array(allChats.prefix(5))
    }
    
    private var suggestions: [Suggestion] {
        SmartSuggestionsService.shared.generateSuggestions(from: allChats)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Приветствие с временем дня
                    WelcomeSection()
                    
                    // Quick Actions
                    QuickActionsSection(selectedAction: $selectedQuickAction)
                    
                    // Недавние чаты
                    if !recentChats.isEmpty {
                        RecentChatsSection(chats: recentChats)
                    }
                    
                    // Статистика дня
                    TodayStatsSection()
                    
                    // Контекстные подсказки
                    if !suggestions.isEmpty {
                        SuggestionsSection(suggestions: suggestions) { suggestion in
                            selectedSuggestion = suggestion
                        }
                    }
                    
                    // Ссылка на шаблоны
                    TemplatesLinkSection()
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Background.primary)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NeoChatLogoView(size: .small, showText: false)
                }
            }
            #if os(iOS)
            .fullScreenCover(item: $selectedQuickAction) { action in
                NavigationStack {
                    QuickActionChatView(action: action)
                }
            }
            .fullScreenCover(item: $selectedSuggestion) { suggestion in
                NavigationStack {
                    SuggestionChatView(suggestion: suggestion)
                }
            }
            #else
            .sheet(item: $selectedQuickAction) { action in
                NavigationStack {
                    QuickActionChatView(action: action)
                }
            }
            .sheet(item: $selectedSuggestion) { suggestion in
                NavigationStack {
                    SuggestionChatView(suggestion: suggestion)
                }
            }
            #endif
        }
    }
}

struct TemplatesLinkSection: View {
    var body: some View {
        NavigationLink {
            TemplatesView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Шаблоны запросов")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text("Сохраните частые запросы для быстрого доступа")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Background.secondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

struct WelcomeSection: View {
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<17: return "Добрый день"
        case 17..<22: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(.primary)
            
            Text("Что будем делать сегодня?")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignSystem.Spacing.md)
    }
}

struct QuickActionsSection: View {
    @Binding var selectedAction: QuickAction?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрые действия")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(QuickAction.allCases) { action in
                    QuickActionCard(action: action) {
                        selectedAction = action
                    }
                }
            }
        }
    }
}

struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(action.color)
                }
                
                Text(action.title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Background.secondary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct RecentChatsSection: View {
    let chats: [Chat]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Недавние чаты")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                NavigationLink("Все") {
                    HistoryView()
                }
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Accent.primary)
            }
            
            VStack(spacing: 8) {
                ForEach(chats.prefix(3)) { chat in
                    NavigationLink {
                        ChatView(chat: chat)
                    } label: {
                        RecentChatRow(chat: chat)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct RecentChatRow: View {
    let chat: Chat
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(chat.mode.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: chat.mode.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(chat.mode.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(chat.updatedAt, style: .relative)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Background.secondary)
        .cornerRadius(12)
    }
}

struct TodayStatsSection: View {
    @Query(sort: [SortDescriptor(\Chat.updatedAt, order: .reverse)]) private var allChats: [Chat]
    
    private var todayChats: [Chat] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return allChats.filter { chat in
            chat.updatedAt >= today && chat.updatedAt < tomorrow
        }
    }
    
    private var todayMessages: Int {
        todayChats.reduce(0) { $0 + ($1.messages?.count ?? 0) }
    }
    
    private var todayTokens: Int {
        todayChats.reduce(0) { $0 + $1.tokenCount }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Статистика за сегодня")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                StatMiniCard(
                    icon: "message.badge",
                    value: "\(todayChats.count)",
                    label: "Чатов",
                    color: DesignSystem.Accent.primary
                )
                
                StatMiniCard(
                    icon: "bubble.left.and.bubble.right",
                    value: "\(todayMessages)",
                    label: "Сообщений",
                    color: DesignSystem.Accent.secondary
                )
                
                StatMiniCard(
                    icon: "number",
                    value: formatNumber(todayTokens),
                    label: "Токенов",
                    color: DesignSystem.Accent.success
                )
            }
        }
    }
}

struct StatMiniCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(.primary)
            
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Background.secondary)
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions

enum QuickAction: String, Identifiable, CaseIterable {
    case explainCode = "explain"
    case writeEmail = "email"
    case planDay = "plan"
    case reviewCode = "review"
    case brainstorm = "brainstorm"
    case summarize = "summarize"
    case translate = "translate"
    case write = "write"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .explainCode: return "Объяснить код"
        case .writeEmail: return "Написать письмо"
        case .planDay: return "Планировать день"
        case .reviewCode: return "Ревью кода"
        case .brainstorm: return "Мозговой штурм"
        case .summarize: return "Резюмировать"
        case .translate: return "Перевести"
        case .write: return "Написать текст"
        }
    }
    
    var icon: String {
        switch self {
        case .explainCode: return "questionmark.circle.fill"
        case .writeEmail: return "envelope.fill"
        case .planDay: return "calendar.badge.clock"
        case .reviewCode: return "checkmark.seal.fill"
        case .brainstorm: return "lightbulb.fill"
        case .summarize: return "doc.text.fill"
        case .translate: return "character.bubble.fill"
        case .write: return "pencil.and.outline"
        }
    }
    
    var color: Color {
        switch self {
        case .explainCode: return .blue
        case .writeEmail: return .green
        case .planDay: return .orange
        case .reviewCode: return .purple
        case .brainstorm: return .yellow
        case .summarize: return .cyan
        case .translate: return .pink
        case .write: return .indigo
        }
    }
    
    var prompt: String {
        switch self {
        case .explainCode:
            return "Объясни этот код подробно, шаг за шагом:"
        case .writeEmail:
            return "Напиши профессиональное письмо на тему:"
        case .planDay:
            return "Помоги спланировать день. Задачи:"
        case .reviewCode:
            return "Проверь этот код и предложи улучшения:"
        case .brainstorm:
            return "Помоги с мозговым штурмом. Тема:"
        case .summarize:
            return "Сделай краткое резюме следующего текста:"
        case .translate:
            return "Переведи на русский язык:"
        case .write:
            return "Напиши текст на тему:"
        }
    }
    
    var mode: AIMode {
        switch self {
        case .explainCode, .reviewCode: return .coding
        case .planDay: return .planner
        default: return .daily
        }
    }
}

struct QuickActionChatView: View {
    let action: QuickAction
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ChatView(chat: nil, initialMode: action.mode, initialPrompt: action.prompt)
            .navigationTitle(action.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") {
                        dismiss()
                    }
                }
                #endif
            }
    }
}

