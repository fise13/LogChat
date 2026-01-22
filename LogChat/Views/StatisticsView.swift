//
//  StatisticsView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Chat.updatedAt, order: .reverse)]) private var allChats: [Chat]
    @Query(sort: [SortDescriptor(\UsageStatistics.date, order: .reverse)]) private var allStatistics: [UsageStatistics]
    
    private var totalChats: Int {
        allChats.filter { !$0.isIncognito }.count
    }
    
    private var totalMessages: Int {
        allChats.reduce(0) { total, chat in
            total + (chat.messages?.count ?? 0)
        }
    }
    
    private var totalTokens: Int {
        allChats.reduce(0) { total, chat in
            total + chat.tokenCount
        }
    }
    
    private var chatsByMode: [(mode: AIMode, count: Int)] {
        let modeCounts = Dictionary(grouping: allChats) { $0.mode }
            .map { (mode: $0.key, count: $0.value.filter { !$0.isIncognito }.count) }
            .sorted { $0.count > $1.count }
        return modeCounts
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Основная статистика
                        VStack(spacing: 16) {
                            StatCard(
                                title: "Всего чатов",
                                value: "\(totalChats)",
                                icon: "message.badge",
                                color: DesignSystem.Accent.primary
                            )
                            
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Сообщений",
                                    value: "\(totalMessages)",
                                    icon: "bubble.left.and.bubble.right",
                                    color: DesignSystem.Accent.secondary
                                )
                                
                                StatCard(
                                    title: "Токенов",
                                    value: "\(totalTokens.formatted())",
                                    icon: "number",
                                    color: DesignSystem.Accent.success
                                )
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        
                        // Статистика по режимам
                        if !chatsByMode.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("По режимам")
                                    .font(DesignSystem.Typography.headline)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                
                                ForEach(chatsByMode, id: \.mode.id) { item in
                                    ModeStatRow(mode: item.mode, count: item.count)
                                }
                            }
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Статистика")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NeoChatLogoView(size: .small, showText: false)
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(DesignSystem.Typography.title)
                .foregroundColor(.primary)
            
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Background.secondary)
        .cornerRadius(16)
    }
}

struct ModeStatRow: View {
    let mode: AIMode
    let count: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(mode.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: mode.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(mode.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.displayName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Text("\(count) чатов")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(count)")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(mode.color)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Background.secondary)
        .cornerRadius(12)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

extension Int {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

