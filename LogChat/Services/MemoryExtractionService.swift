//
//  MemoryExtractionService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

@MainActor
class MemoryExtractionService {
    static let shared = MemoryExtractionService()
    
    private init() {}
    
    /// Использует AI для анализа диалога и предлагает важные факты для сохранения
    func suggestMemories(from messages: [Message], using aiService: AIService) async -> [MemorySuggestion] {
        // Проверяем, включены ли предложения памяти
        guard UserDefaults.standard.bool(forKey: "autoMemorySuggestionsEnabled") else {
            return []
        }
        
        guard !messages.isEmpty else { return [] }
        
        // Берем последние сообщения для анализа (не более 15)
        let recentMessages = Array(messages.suffix(15))
        let conversationText = recentMessages
            .map { "\($0.role.rawValue): \($0.content)" }
            .joined(separator: "\n")
        
        // Если диалог слишком короткий, не предлагаем
        if conversationText.count < 100 {
            return []
        }
        
        // Проверяем, что последнее сообщение от ассистента (только после ответа предлагаем)
        guard let lastMessage = messages.last,
              lastMessage.role == .assistant else {
            return []
        }
        
        // Создаем промпт для AI анализа
        let analysisPrompt = """
        Analyze this conversation and identify 1-3 important facts or pieces of information about the user that would be valuable to remember for future personalization.
        
        Focus on:
        - Personal details: name, occupation, location, interests, hobbies
        - Preferences: likes, dislikes, communication style, preferences
        - Projects/work: current projects, goals, tasks, work context
        - Important facts: specific information that helps personalize responses
        
        IMPORTANT RULES:
        1. Only suggest information that is CLEARLY stated in the conversation
        2. Only suggest if it would genuinely help personalize future responses
        3. Skip generic or obvious information
        4. Maximum 3 suggestions (most important ones)
        5. Each suggestion must have importance >= 5
        6. Be specific and actionable
        
        Conversation:
        \(conversationText)
        
        Respond ONLY with valid JSON (no markdown, no explanations):
        {
          "suggestions": [
            {
              "type": "profile|preference|project|fact",
              "key": "short_unique_key",
              "content": "Clear, concise information (1-2 sentences max)",
              "importance": 7,
              "reason": "Brief explanation why this matters"
            }
          ]
        }
        
        If no valuable memories found, return: {"suggestions": []}
        """
        
        do {
            let analysisMessage = Message(content: analysisPrompt, role: .user)
            let stream = try await aiService.sendMessage(
                messages: [analysisMessage],
                mode: .daily,
                model: nil
            )
            
            // Собираем ответ
            var responseText = ""
            for try await chunk in stream {
                responseText += chunk
            }
            
            // Парсим JSON ответ
            let suggestions = parseAISuggestions(from: responseText)
            
            // Фильтруем только важные (>= 5)
            let filtered = suggestions.filter { $0.importance >= 5 }
            
            // Ограничиваем 3 предложениями
            return Array(filtered.prefix(3))
            
        } catch {
            print("⚠️ Error getting AI memory suggestions: \(error)")
            return []
        }
    }
    
    /// Парсит JSON ответ от AI с предложениями памяти
    private func parseAISuggestions(from text: String) -> [MemorySuggestion] {
        var suggestions: [MemorySuggestion] = []
        
        // Извлекаем JSON из ответа (может быть обернут в markdown code blocks)
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Удаляем markdown code blocks если есть
        if jsonText.hasPrefix("```") {
            let lines = jsonText.components(separatedBy: "\n")
            jsonText = lines
                .dropFirst() // Remove first ``` line
                .dropLast() // Remove last ``` line
                .joined(separator: "\n")
        }
        
        // Ищем JSON объект (аккуратно работаем с индексами, чтобы избежать крэшей)
        if let startRange = jsonText.range(of: "{"),
           let endRange = jsonText.range(of: "}", options: .backwards) {
            let startIndex = startRange.lowerBound
            let endIndexExclusive = jsonText.index(after: endRange.lowerBound)
            
            if startIndex < endIndexExclusive, endIndexExclusive <= jsonText.endIndex {
                jsonText = String(jsonText[startIndex..<endIndexExclusive])
            }
        }
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            print("⚠️ Failed to convert JSON text to data")
            return suggestions
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let suggestionsArray = json["suggestions"] as? [[String: Any]] else {
                return suggestions
            }
            
            for suggestionDict in suggestionsArray {
                guard let typeString = suggestionDict["type"] as? String,
                      let type = MemoryType(rawValue: typeString),
                      let key = suggestionDict["key"] as? String,
                      let content = suggestionDict["content"] as? String else {
                    continue
                }
                
                // Importance может быть Int или может отсутствовать
                let importance: Int
                if let importanceValue = suggestionDict["importance"] as? Int {
                    importance = max(1, min(10, importanceValue))
                } else {
                    importance = 5 // Default
                }
                
                let reason = suggestionDict["reason"] as? String
                
                let suggestion = MemorySuggestion(
                    type: type,
                    key: key,
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    importance: importance,
                    reason: reason?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                suggestions.append(suggestion)
            }
        } catch {
            print("⚠️ Error parsing AI suggestions JSON: \(error)")
            print("⚠️ JSON text: \(jsonText.prefix(500))")
        }
        
        return suggestions
    }
    
    /// Анализирует диалог и извлекает важную информацию для сохранения
    func extractMemories(from messages: [Message], using aiService: AIService) async -> [(type: MemoryType, key: String, content: String, importance: Int)] {
        var extractedMemories: [(type: MemoryType, key: String, content: String, importance: Int)] = []
        
        let conversationText = messages
            .map { "\($0.role.rawValue): \($0.content)" }
            .joined(separator: "\n")
        
        let importanceService = MemoryImportanceService.shared
        let minThreshold = importanceService.getMinimumImportanceThreshold()
        
        // Извлекаем проекты
        if let (key, projectPattern) = extractProject(from: conversationText) {
            let importance = importanceService.calculateImportance(
                content: projectPattern,
                type: .project,
                context: conversationText
            )
            
            // Filter out low importance memories
            if importance >= minThreshold {
                extractedMemories.append((
                    type: .project,
                    key: key,
                    content: projectPattern,
                    importance: importance
                ))
            }
        }
        
        // Извлекаем предпочтения
        for (key, preferencePattern) in extractPreferences(from: conversationText) {
            let importance = importanceService.calculateImportance(
                content: preferencePattern,
                type: .preference,
                context: conversationText
            )
            
            if importance >= minThreshold {
                extractedMemories.append((
                    type: .preference,
                    key: key,
                    content: preferencePattern,
                    importance: importance
                ))
            }
        }
        
        // Извлекаем профильную информацию
        for (key, profileInfo) in extractProfileInfo(from: conversationText) {
            let importance = importanceService.calculateImportance(
                content: profileInfo,
                type: .profile,
                context: conversationText
            )
            
            if importance >= minThreshold {
                extractedMemories.append((
                    type: .profile,
                    key: key,
                    content: profileInfo,
                    importance: importance
                ))
            }
        }
        
        return extractedMemories
    }
    
    // MARK: - Pattern Extraction (Simplified)
    
    private func extractProject(from text: String) -> (key: String, content: String)? {
        let projectKeywords = ["project", "проект", "работаю над", "working on", "developing", "разрабатываю"]
        
        for keyword in projectKeywords {
            if text.localizedCaseInsensitiveContains(keyword) {
                let content = extractContextAround(keyword, in: text, length: 80)
                // Try to extract project name
                let projectName = extractProjectName(from: content, keyword: keyword) ?? "current_project"
                return (key: projectName, content: content)
            }
        }
        
        return nil
    }
    
    private func extractProjectName(from text: String, keyword: String) -> String? {
        // Try to find project name after keyword
        let lowerText = text.lowercased()
        if let range = lowerText.range(of: keyword) {
            let after = String(text[range.upperBound...])
            let words = after.split(separator: " ").prefix(3)
            if !words.isEmpty {
                // Take first meaningful word as project name
                let name = words.joined(separator: "_")
                    .replacingOccurrences(of: "[^a-zA-Zа-ЯА-Я0-9_]", with: "", options: .regularExpression)
                return name.isEmpty ? nil : name.lowercased()
            }
        }
        return nil
    }
    
    private func extractPreferences(from text: String) -> [(key: String, content: String)] {
        var preferences: [(key: String, content: String)] = []
        
        let preferencePatterns: [(keywords: [String], key: String)] = [
            (["prefer", "нравится", "like", "люблю"], "likes"),
            (["не люблю", "don't like", "hate", "ненавижу", "dislike"], "dislikes"),
            (["лучше", "better", "предпочитаю", "prefer"], "preferences"),
            (["обычно", "usually", "typically", "как правило"], "habits"),
            (["стиль", "style", "формат", "format"], "style_preference")
        ]
        
        for pattern in preferencePatterns {
            for keyword in pattern.keywords {
                if text.localizedCaseInsensitiveContains(keyword) {
                    let content = extractContextAround(keyword, in: text, length: 60)
                    preferences.append((key: pattern.key, content: content))
                    break // Only one match per pattern
                }
            }
        }
        
        return preferences
    }
    
    private func extractProfileInfo(from text: String) -> [(key: String, content: String)] {
        var profileInfo: [(key: String, content: String)] = []
        
        let profilePatterns: [(keywords: [String], key: String)] = [
            (["меня зовут", "my name is", "я -", "я —"], "name"),
            (["работаю", "work", "working as", "работаю в"], "occupation"),
            (["живу", "live", "located in", "находись"], "location"),
            (["увлекаюсь", "interested in", "hobby", "хобби"], "interests"),
            (["изучаю", "learning", "studying", "учусь"], "learning")
        ]
        
        for pattern in profilePatterns {
            for keyword in pattern.keywords {
                if text.localizedCaseInsensitiveContains(keyword) {
                    let content = extractContextAround(keyword, in: text, length: 60)
                    profileInfo.append((key: pattern.key, content: content))
                    break
                }
            }
        }
        
        return profileInfo
    }
    
    private func extractContextAround(_ keyword: String, in text: String, length: Int) -> String {
        guard let range = text.localizedStandardRange(of: keyword) else {
            return ""
        }
        
        let start = text.index(max(text.startIndex, range.lowerBound), offsetBy: -length/2, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(min(text.endIndex, range.upperBound), offsetBy: length/2, limitedBy: text.endIndex) ?? text.endIndex
        
        var extracted = String(text[start..<end])
        
        // Очищаем от лишних символов
        extracted = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        if extracted.count > 100 {
            extracted = String(extracted.prefix(100)) + "..."
        }
        
        return extracted
    }
}

