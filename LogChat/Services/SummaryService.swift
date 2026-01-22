//
//  SummaryService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

class SummaryService {
    static let shared = SummaryService()
    
    // Создание краткого резюме чата
    func createSummary(messages: [Message]) -> String {
        guard !messages.isEmpty else { return "" }
        
        // Берем первые и последние сообщения + ключевые моменты
        var summaryParts: [String] = []
        
        // Первое сообщение пользователя
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let preview = String(firstUserMessage.content.prefix(100))
            summaryParts.append("Начало: \(preview)...")
        }
        
        // Закрепленные сообщения
        let pinned = messages.filter { $0.isPinned }
        if !pinned.isEmpty {
            summaryParts.append("Ключевые моменты: \(pinned.count) закрепленных сообщений")
        }
        
        // Последнее сообщение
        if let lastMessage = messages.last {
            let preview = String(lastMessage.content.prefix(100))
            summaryParts.append("Последнее: \(preview)...")
        }
        
        return summaryParts.joined(separator: "\n")
    }
    
    // Автоматическая суммаризация через AI (требует API вызов)
    func createAISummary(messages: [Message], completion: @escaping (String?) -> Void) {
        // В реальном приложении здесь был бы вызов AI для создания резюме
        // Пока возвращаем базовое резюме
        let summary = createSummary(messages: messages)
        completion(summary)
    }
}

