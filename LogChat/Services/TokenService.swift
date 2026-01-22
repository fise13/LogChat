//
//  TokenService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

class TokenService {
    static let shared = TokenService()
    
    // Примерная оценка токенов (1 токен ≈ 4 символа для английского, больше для других языков)
    func estimateTokens(text: String) -> Int {
        // Упрощенная оценка: примерно 1 токен на 4 символа
        return max(1, text.count / 4)
    }
    
    func estimateTokensForMessages(_ messages: [Message]) -> Int {
        var total = 0
        for message in messages {
            total += estimateTokens(text: message.content)
            if message.imageData != nil {
                total += 170 // Примерная стоимость изображения
            }
        }
        return total
    }
    
    // Лимит контекста (можно настроить)
    var contextLimit: Int {
        UserDefaults.standard.integer(forKey: "contextTokenLimit") > 0 
            ? UserDefaults.standard.integer(forKey: "contextTokenLimit")
            : 8000 // По умолчанию 8k токенов
    }
    
    func shouldTrimMessages(_ messages: [Message]) -> Bool {
        return estimateTokensForMessages(messages) > contextLimit
    }
    
    func trimMessages(_ messages: [Message], keepPinned: Bool = true) -> [Message] {
        // Создаем копию массива для работы
        let messagesCopy = messages
        
        // Всегда оставляем закрепленные сообщения
        if keepPinned {
            let pinned = messagesCopy.filter { $0.isPinned }
            let unpinned = messagesCopy.filter { !$0.isPinned }
            
            // Если закрепленные уже превышают лимит, оставляем только их
            if estimateTokensForMessages(pinned) > contextLimit {
                return pinned
            }
            
            // Оставляем последние N сообщений, которые влезают в лимит
            var tokens = estimateTokensForMessages(pinned)
            var trimmed: [Message] = pinned
            
            for message in unpinned.reversed() {
                let messageTokens = estimateTokens(text: message.content)
                if tokens + messageTokens <= contextLimit {
                    trimmed.insert(message, at: pinned.count)
                    tokens += messageTokens
                } else {
                    break
                }
            }
            
            return trimmed
        } else {
            // Просто оставляем последние N сообщений
            var tokens = 0
            var trimmed: [Message] = []
            
            for message in messagesCopy.reversed() {
                let messageTokens = estimateTokens(text: message.content)
                if tokens + messageTokens <= contextLimit {
                    trimmed.insert(message, at: 0)
                    tokens += messageTokens
                } else {
                    break
                }
            }
            
            return trimmed
        }
    }
}

