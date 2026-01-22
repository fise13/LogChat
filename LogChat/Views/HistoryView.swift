//
//  HistoryView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Chat> { !$0.isIncognito },
        sort: [SortDescriptor(\Chat.updatedAt, order: .reverse)]
    ) private var allChats: [Chat]
    @State private var selectedMode: AIMode? = nil
    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    
    // Кэшируем теги
    private var allTags: [String] {
        let tags = allChats.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }
    
    // Оптимизированная фильтрация с кэшированием
    @State private var cachedFilteredChats: [Chat] = []
    @State private var lastFilterHash: Int = 0
    
    private var filteredChats: [Chat] {
        // Вычисляем хэш фильтров для кэширования
        let filterHash = hashValue(selectedMode: selectedMode, searchText: searchText, selectedTag: selectedTag, chatsCount: allChats.count)
        
        // Используем кэш если фильтры не изменились
        if filterHash == lastFilterHash && !cachedFilteredChats.isEmpty {
            return cachedFilteredChats
        }
        
        // Фильтруем только чаты с сообщениями
        var chats = allChats.filter { !($0.messages?.isEmpty ?? true) }
        
        // Фильтр по режиму
        if let mode = selectedMode {
            chats = chats.filter { $0.mode == mode }
        }
        
        // Фильтр по тегу
        if let tag = selectedTag {
            chats = chats.filter { $0.tags.contains(tag) }
        }
        
        // Поиск (оптимизирован - только по заголовку для производительности)
        if !searchText.isEmpty {
            let lowercased = searchText.lowercased()
            chats = chats.filter { $0.title.lowercased().contains(lowercased) }
        }
        
        // Сортировка
        let sorted = chats.sorted { chat1, chat2 in
            if chat1.isPinned != chat2.isPinned {
                return chat1.isPinned
            }
            return chat1.updatedAt > chat2.updatedAt
        }
        
        // Обновляем кэш
        cachedFilteredChats = sorted
        lastFilterHash = filterHash
        
        return sorted
    }
    
    private func hashValue(selectedMode: AIMode?, searchText: String, selectedTag: String?, chatsCount: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(selectedMode?.rawValue)
        hasher.combine(searchText)
        hasher.combine(selectedTag)
        hasher.combine(chatsCount)
        return hasher.finalize()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                if filteredChats.isEmpty {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Accent.primary.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "message.badge")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(DesignSystem.Accent.primary.opacity(0.6))
                        }
                        
                        VStack(spacing: 8) {
                            Text("No chats yet")
                                .font(DesignSystem.Typography.title3)
                                .foregroundColor(.primary)
                            
                            Text("Start a new conversation to see it here")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(DesignSystem.Spacing.xl)
                } else {
                    List {
                        ForEach(filteredChats) { chat in
                            NavigationLink {
                                ChatView(chat: chat)
                            } label: {
                                ChatRowView(chat: chat)
                            }
                            .listRowInsets(EdgeInsets(
                                top: 12,
                                leading: DesignSystem.Spacing.md,
                                bottom: 12,
                                trailing: DesignSystem.Spacing.md
                            ))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteChat(chat)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                                
                                Button {
                                    exportChat(chat)
                                } label: {
                                    Label("Экспорт", systemImage: "square.and.arrow.up")
                                }
                                .tint(DesignSystem.Accent.primary)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    togglePin(chat)
                                } label: {
                                    Label(
                                        chat.isPinned ? "Открепить" : "Закрепить",
                                        systemImage: chat.isPinned ? "pin.slash" : "pin"
                                    )
                                }
                                .tint(DesignSystem.Accent.warning)
                            }
                        }
                        .onDelete(perform: deleteChats)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search chats")
                }
            }
            .safeAreaInset(edge: .top) {
                if !allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagChip(
                                title: "Все",
                                isSelected: selectedTag == nil && selectedMode == nil,
                                color: DesignSystem.Accent.primary
                            ) {
                                selectedTag = nil
                                selectedMode = nil
                            }
                            
                            if selectedMode == nil {
                                ForEach(allTags, id: \.self) { tag in
                                    TagChip(
                                        title: tag,
                                        isSelected: selectedTag == tag,
                                        color: getTagColor(tag)
                                    ) {
                                        selectedTag = selectedTag == tag ? nil : tag
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                    .background(DesignSystem.Background.secondary)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NeoChatLogoView(size: .small, showText: false)
                }
                
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #endif
            }
            .refreshable {
                // Очищаем кэш при обновлении
                cachedFilteredChats = []
                lastFilterHash = 0
            }
            .onChange(of: allChats.count) { _, _ in
                // Сбрасываем кэш при изменении количества чатов
                cachedFilteredChats = []
                lastFilterHash = 0
            }
            .onChange(of: selectedMode) { _, _ in
                cachedFilteredChats = []
                lastFilterHash = 0
            }
            .onChange(of: searchText) { _, _ in
                cachedFilteredChats = []
                lastFilterHash = 0
            }
            .onChange(of: selectedTag) { _, _ in
                cachedFilteredChats = []
                lastFilterHash = 0
            }
        }
    }
    
    private func deleteChats(at offsets: IndexSet) {
        for index in offsets {
            let chat = filteredChats[index]
            modelContext.delete(chat)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting chat: \(error)")
        }
    }
    
    private func deleteChat(_ chat: Chat) {
        modelContext.delete(chat)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting chat: \(error)")
        }
    }
    
    private func togglePin(_ chat: Chat) {
        chat.isPinned.toggle()
        do {
            try modelContext.save()
        } catch {
            print("Error toggling pin: \(error)")
        }
    }
    
    private func exportChat(_ chat: Chat) {
        #if os(iOS)
        let markdown = ExportService.shared.exportChatToMarkdown(chat)
        let activityVC = UIActivityViewController(
            activityItems: [markdown],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
        #else
        // macOS implementation - use NSPanel or file picker
        let markdown = ExportService.shared.exportChatToMarkdown(chat)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(chat.title).md"
        panel.allowedContentTypes = [.plainText]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        #endif
    }
    
    private func getTagColor(_ tag: String) -> Color {
        let colors: [Color] = [
            DesignSystem.Accent.primary,
            DesignSystem.Accent.secondary,
            DesignSystem.Accent.success,
            DesignSystem.Accent.warning,
            .purple,
            .pink
        ]
        let index = abs(tag.hashValue) % colors.count
        return colors[index]
    }
}

struct ChatRowView: View {
    let chat: Chat
    
    // Кэшируем последнее сообщение для производительности
    private var lastMessagePreview: String? {
        guard let messages = chat.messages, !messages.isEmpty else { return nil }
        // Используем последнее сообщение (уже отсортированы по updatedAt)
        return messages.last?.content
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Title and preview - ChatGPT style
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(chat.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Accent.warning)
                    }
                }
                
                // Preview of last message - оптимизировано
                if let preview = lastMessagePreview {
                    Text(preview)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
