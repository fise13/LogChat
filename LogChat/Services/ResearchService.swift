//
//  ResearchService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

@MainActor
class ResearchService {
    static let shared = ResearchService()
    
    private init() {}
    
    /// Определяет, нужен ли веб-поиск для запроса
    func needsWebSearch(query: String) -> Bool {
        // Проверяем, настроен ли веб-поиск
        guard SearchService.shared.isConfigured else {
            return false
        }
        
        let lowercased = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Слишком короткие запросы не требуют поиска
        guard lowercased.count > 3 else {
            return false
        }
        
        // Ключевые слова, требующие актуальной информации
        let timeKeywords = [
            "цена", "price", "стоимость", "cost", "купить", "buy", "продать", "sell",
            "где", "where", "когда", "when", "сколько", "how much", "how many",
            "новости", "news", "актуальные", "current", "latest", "последние",
            "сейчас", "now", "сегодня", "today", "вчера", "yesterday",
            "текущие", "recent", "свежие", "fresh", "обновление", "update",
            "товары", "products", "магазин", "shop", "store", "интернет", "online",
            "сайт", "website", "курс", "rate", "exchange", "погода", "weather",
            "события", "events", "расписание", "schedule", "рейтинг", "rating",
            "отзывы", "reviews", "статистика", "statistics", "тренды", "trends"
        ]
        
        // Вопросы обычно требуют поиска
        let questionWords = ["что", "what", "кто", "who", "как", "how", "почему", "why", "зачем", "when", "где", "where"]
        let hasQuestionWord = questionWords.contains { lowercased.hasPrefix($0 + " ") || lowercased.contains(" " + $0 + " ") }
        
        // Проверяем наличие ключевых слов
        let hasTimeKeyword = timeKeywords.contains { keyword in
            lowercased.contains(keyword)
        }
        
        // Проверяем наличие вопросительных знаков
        let hasQuestionMark = query.contains("?") || query.contains("？")
        
        // Проверяем наличие временных маркеров
        let hasTimeMarker = lowercased.contains("2024") || lowercased.contains("2025") || 
                           lowercased.contains("this year") || lowercased.contains("this month") ||
                           lowercased.contains("этот год") || lowercased.contains("этот месяц")
        
        // Если есть вопрос или временные маркеры, вероятно нужен поиск
        if hasQuestionWord || hasQuestionMark || hasTimeMarker {
            return true
        }
        
        // Если есть ключевые слова, требующие актуальной информации
        if hasTimeKeyword {
            return true
        }
        
        return false
    }
    
    /// Формирует поисковый запрос из пользовательского запроса
    func buildSearchQuery(from userQuery: String) -> String {
        var query = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Удаляем вопросительные знаки (они не нужны для поиска)
        query = query.replacingOccurrences(of: "?", with: "")
        query = query.replacingOccurrences(of: "？", with: "")
        
        // Удаляем лишние пробелы
        query = query.replacingOccurrences(of: "  ", with: " ")
        
        // Ограничиваем длину запроса (слишком длинные запросы могут быть неэффективны)
        if query.count > 100 {
            let words = query.split(separator: " ")
            if words.count > 10 {
                query = words.prefix(10).joined(separator: " ")
            }
        }
        
        return query
    }
    
    /// Форматирует результаты поиска для передачи в AI
    func formatSearchResults(_ results: [SearchResult]) -> String {
        guard !results.isEmpty else {
            return ""
        }
        
        var formatted = "\n\n--- WEB SEARCH RESULTS ---\n"
        formatted += "Found \(results.count) results:\n\n"
        
        for (index, result) in results.enumerated() {
            formatted += "[\(index + 1)] \(result.title)\n"
            formatted += "URL: \(result.url)\n"
            formatted += "\(result.snippet)\n"
            if let source = result.source {
                formatted += "Source: \(source)\n"
            }
            formatted += "\n"
        }
        
        formatted += "--- END WEB SEARCH RESULTS ---\n"
        formatted += "Use the information above to provide accurate, up-to-date answers. Always cite sources."
        
        return formatted
    }
}

