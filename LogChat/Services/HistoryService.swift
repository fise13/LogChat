//
//  HistoryService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@MainActor
class HistoryService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func saveChat(_ chat: Chat) {
        // Устанавливаем updatedAt
        chat.updatedAt = Date()
        
        // Вставляем чат в контекст
        modelContext.insert(chat)
        
        // Также вставляем все сообщения в контекст
        if let messages = chat.messages {
            for message in messages {
                modelContext.insert(message)
                message.chat = chat
            }
        }
        
        do {
            // Сохраняем контекст
            try modelContext.save()
            
            // Синхронизируем с Firebase
            if FirebaseService.shared.isFirebaseAvailable {
                Task {
                    try? await FirebaseService.shared.syncChats(context: modelContext)
                }
            }
            
            // Отправляем уведомление без задержки для лучшей производительности
            NotificationCenter.default.post(name: NSNotification.Name("ChatSaved"), object: nil)
        } catch {
            print("❌ Error saving chat: \(error)")
        }
    }
    
    func loadChats(mode: AIMode? = nil) -> [Chat] {
        var descriptor: FetchDescriptor<Chat>
        
        if let mode = mode {
            let modeValue = mode.rawValue
            descriptor = FetchDescriptor<Chat>(
                predicate: #Predicate<Chat> { $0.modeRawValue == modeValue },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Chat>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }
        
        do {
            let chats = try modelContext.fetch(descriptor)
            print("📋 Loaded \(chats.count) chats from database")
            for chat in chats {
                print("  - \(chat.title), incognito: \(chat.isIncognito), messages: \(chat.messages?.count ?? 0)")
            }
            return chats
        } catch {
            print("❌ Error loading chats: \(error)")
            return []
        }
    }
    
    func deleteChat(_ chat: Chat) {
        modelContext.delete(chat)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting chat: \(error)")
        }
    }
    
    func updateChat(_ chat: Chat) {
        // Убеждаемся, что чат в контексте
        modelContext.insert(chat)
        
        chat.updatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Синхронизируем с Firebase
            if FirebaseService.shared.isFirebaseAvailable {
                Task {
                    try? await FirebaseService.shared.syncChats(context: modelContext)
                }
            }
            
            // Отправляем уведомление без задержки
            NotificationCenter.default.post(name: NSNotification.Name("ChatSaved"), object: nil)
        } catch {
            print("❌ Error updating chat: \(error)")
        }
    }
    
    func addMessage(_ message: ChatMessage, to chat: Chat) {
        // Убеждаемся, что чат в контексте
        modelContext.insert(chat)
        modelContext.insert(message)
        
        if chat.messages == nil {
            chat.messages = []
        }
        chat.messages?.append(message)
        chat.updatedAt = Date()
        
        // Убеждаемся, что сообщение связано с чатом
        message.chat = chat
        
        do {
            try modelContext.save()
            
            // Синхронизируем с Firebase
            if FirebaseService.shared.isFirebaseAvailable {
                Task {
                    try? await FirebaseService.shared.syncChats(context: modelContext)
                }
            }
            
            // Отправляем уведомление без задержки
            NotificationCenter.default.post(name: NSNotification.Name("ChatSaved"), object: nil)
        } catch {
            print("❌ Error adding message: \(error)")
        }
    }
}

