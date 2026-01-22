//
//  SmartSuggestionsService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@MainActor
class SmartSuggestionsService {
    static let shared = SmartSuggestionsService()
    
    private init() {}
    
    /// Генерирует контекстные подсказки на основе истории чатов
    func generateSuggestions(
        from chats: [Chat],
        currentTime: Date = Date()
    ) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        // 1. Предлагаем продолжить недавние чаты
        let recentChats = chats
            .filter { !$0.isIncognito }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
        
        for chat in recentChats {
            let hoursSinceUpdate = currentTime.timeIntervalSince(chat.updatedAt) / 3600
            if hoursSinceUpdate < 24 {
                suggestions.append(.continueChat(chat: chat))
            }
        }
        
        // 2. Предлагаем шаблоны на основе времени дня
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 8..<12:
            suggestions.append(.timeBased(title: "Планирование дня", prompt: "Помоги спланировать задачи на сегодня", mode: .planner))
        case 12..<14:
            suggestions.append(.timeBased(title: "Обеденный перерыв", prompt: "Расскажи что-то интересное", mode: .daily))
        case 17..<20:
            suggestions.append(.timeBased(title: "Подведение итогов", prompt: "Помоги подвести итоги дня", mode: .planner))
        default:
            break
        }
        
        // 3. Предлагаем на основе популярных режимов
        let modeUsage = Dictionary(grouping: chats) { $0.mode }
            .map { (mode: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        
        if let mostUsedMode = modeUsage.first, mostUsedMode.count > 5 {
            let mode = mostUsedMode.mode
            let prompt = getPromptForMode(mode)
            suggestions.append(.modeBased(title: "Продолжи работу с \(mode.displayName)", prompt: prompt, mode: mode))
        }
        
        return Array(suggestions.prefix(5)) // Максимум 5 подсказок
    }
    
    private func getPromptForMode(_ mode: AIMode) -> String {
        switch mode {
        case .coding:
            return "Помоги с программированием. Задача:"
        case .planner:
            return "Помоги с планированием. Тема:"
        case .daily:
            return "Вопрос или задача:"
        case .research:
            return "Исследовать тему:"
        }
    }
}

enum Suggestion: Identifiable {
    case continueChat(chat: Chat)
    case timeBased(title: String, prompt: String, mode: AIMode)
    case modeBased(title: String, prompt: String, mode: AIMode)
    
    var id: String {
        switch self {
        case .continueChat(let chat):
            return "continue_\(chat.id.uuidString)"
        case .timeBased(let title, _, _):
            return "time_\(title)"
        case .modeBased(let title, _, _):
            return "mode_\(title)"
        }
    }
    
    var title: String {
        switch self {
        case .continueChat(let chat):
            return "Продолжи: \(chat.title)"
        case .timeBased(let title, _, _):
            return title
        case .modeBased(let title, _, _):
            return title
        }
    }
    
    var prompt: String {
        switch self {
        case .continueChat:
            return "Продолжим обсуждение"
        case .timeBased(_, let prompt, _):
            return prompt
        case .modeBased(_, let prompt, _):
            return prompt
        }
    }
    
    var mode: AIMode {
        switch self {
        case .continueChat(let chat):
            return chat.mode
        case .timeBased(_, _, let mode):
            return mode
        case .modeBased(_, _, let mode):
            return mode
        }
    }
    
    var chat: Chat? {
        switch self {
        case .continueChat(let chat):
            return chat
        default:
            return nil
        }
    }
}

