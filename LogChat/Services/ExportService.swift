//
//  ExportService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@MainActor
class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    func exportChatToMarkdown(_ chat: Chat) -> String {
        var markdown = "# \(chat.title)\n\n"
        markdown += "**Режим:** \(chat.mode.displayName)\n"
        markdown += "**Дата создания:** \(formatDate(chat.createdAt))\n"
        markdown += "**Последнее обновление:** \(formatDate(chat.updatedAt))\n"
        
        if !chat.tags.isEmpty {
            markdown += "**Теги:** \(chat.tags.joined(separator: ", "))\n"
        }
        
        if chat.tokenCount > 0 {
            markdown += "**Токенов использовано:** \(chat.tokenCount)\n"
        }
        
        markdown += "\n---\n\n"
        
        // Сортируем сообщения по времени
        if let messages = chat.messages {
            let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
            
            for message in sortedMessages {
                let role = message.role == .user ? "**Вы:**" : "**AI:**"
                let timestamp = formatTime(message.timestamp)
                
                markdown += "\(role) \(timestamp)\n\n"
                
                // Форматируем код блоки
                let content = formatMarkdownContent(message.content)
                markdown += "\(content)\n\n"
                
                markdown += "---\n\n"
            }
        }
        
        return markdown
    }
    
    func exportChatToPlainText(_ chat: Chat) -> String {
        var text = "\(chat.title)\n"
        text += "Режим: \(chat.mode.displayName)\n"
        text += "Дата: \(formatDate(chat.createdAt))\n\n"
        
        if let messages = chat.messages {
            let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
            
            for message in sortedMessages {
                let role = message.role == .user ? "Вы" : "AI"
                let timestamp = formatTime(message.timestamp)
                text += "[\(timestamp)] \(role):\n"
                text += "\(message.content)\n\n"
            }
        }
        
        return text
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatMarkdownContent(_ content: String) -> String {
        // Простое форматирование - код блоки уже в markdown формате
        return content
    }
}

