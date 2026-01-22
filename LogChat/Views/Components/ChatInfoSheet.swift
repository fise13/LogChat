//
//  ChatInfoSheet.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct ChatInfoSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var chat: Chat
    @Environment(\.dismiss) var dismiss
    
    @State private var newTag: String = ""
    
    private let availableTags = ["работа", "личное", "проект", "идея", "вопрос", "код", "обучение"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $chat.title)
                } header: {
                    Text("Основное")
                }
                
                Section {
                    Toggle("Закрепить", isOn: $chat.isPinned)
                } header: {
                    Text("Настройки")
                }
                
                Section {
                    // Быстрые теги
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableTags, id: \.self) { tag in
                                Button {
                                    toggleTag(tag)
                                } label: {
                                    Text(tag)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(chat.tags.contains(tag) ? .white : DesignSystem.Accent.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(chat.tags.contains(tag) ? DesignSystem.Accent.primary : DesignSystem.Accent.primary.opacity(0.1))
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    
                    // Пользовательские теги
                    HStack {
                        TextField("Новый тег", text: $newTag)
                            .onSubmit {
                                addCustomTag()
                            }
                        Button("Добавить") {
                            addCustomTag()
                        }
                        .disabled(newTag.isEmpty)
                    }
                    
                    // Текущие теги
                    if !chat.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chat.tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(DesignSystem.Typography.caption)
                                        Button {
                                            removeTag(tag)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(DesignSystem.Accent.primary.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Теги")
                } footer: {
                    Text("Теги помогают организовать и быстро находить чаты")
                }
            }
            .navigationTitle("Информация о чате")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        save()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") {
                        save()
                    }
                }
                #endif
            }
        }
    }
    
    private func toggleTag(_ tag: String) {
        if chat.tags.contains(tag) {
            chat.tags.removeAll { $0 == tag }
        } else {
            chat.tags.append(tag)
        }
    }
    
    private func addCustomTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !chat.tags.contains(trimmed) {
            chat.tags.append(trimmed)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        chat.tags.removeAll { $0 == tag }
    }
    
    private func save() {
        chat.updatedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving chat: \(error)")
        }
    }
}

