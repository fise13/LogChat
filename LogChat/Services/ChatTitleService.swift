//
//  ChatTitleService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

@MainActor
class ChatTitleService {
    static let shared = ChatTitleService()
    
    private let aiService = AIService.shared
    
    private init() {}
    
    /// Генерирует название чата на основе первых сообщений
    func generateTitle(for messages: [Message], mode: AIMode) async -> String? {
        // Нужно минимум одно сообщение пользователя и один ответ AI
        guard messages.count >= 2,
              let firstUserMessage = messages.first(where: { $0.role == .user }),
              let firstAssistantMessage = messages.first(where: { $0.role == .assistant }) else {
            return nil
        }
        
        // Если уже есть хорошее название (не дефолтное), не генерируем новое
        // Это проверяется в ChatViewModel
        
        // Формируем промпт для генерации названия
        let userQuery = firstUserMessage.content.prefix(200) // Берем первые 200 символов
        let assistantResponse = firstAssistantMessage.content.prefix(300) // Берем первые 300 символов
        
        let prompt = """
        Based on this conversation, generate a short, descriptive title (maximum 5-6 words) in the same language as the conversation.
        The title should capture the main topic or question.
        Return ONLY the title, nothing else.
        
        User: \(userQuery)
        Assistant: \(assistantResponse)
        
        Title:
        """
        
        do {
            // Используем быструю модель для генерации названия
            let defaultModel = LLMModel.defaultModel
            let titleResponse = try await aiService.sendMessage(
                messages: [
                    Message(
                        content: prompt,
                        role: .user
                    )
                ],
                mode: mode,
                model: defaultModel,
                imageData: nil,
                memoryContext: nil,
                webSearchContext: nil
            )
            
            // Собираем ответ
            var title = ""
            for try await chunk in titleResponse {
                title += chunk
            }
            
            // Очищаем название от лишних символов
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            title = title.replacingOccurrences(of: "\"", with: "")
            title = title.replacingOccurrences(of: "'", with: "")
            
            // Ограничиваем длину
            if title.count > 60 {
                title = String(title.prefix(57)) + "..."
            }
            
            // Если название слишком короткое или пустое, возвращаем nil
            if title.count < 3 {
                return nil
            }
            
            return title
        } catch {
            print("⚠️ Error generating chat title: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Генерирует простое название из первого сообщения пользователя
    func generateSimpleTitle(from firstMessage: String) -> String {
        let title = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Удаляем знаки препинания в конце
        let cleaned = title.replacingOccurrences(of: "[?!.]$", with: "", options: .regularExpression)
        
        // Ограничиваем длину
        if cleaned.count > 50 {
            return String(cleaned.prefix(47)) + "..."
        }
        
        return cleaned.isEmpty ? "New Chat" : cleaned
    }
}
