//
//  ChatViewModel.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
#if os(iOS)
import UIKit
#endif

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentMode: AIMode = .daily
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var connectionState: ConnectionState = .connected
    #if os(iOS)
    @Published var selectedImage: UIImage?
    #endif
    @Published var streamingText: String = ""
    @Published var isStreaming: Bool = false
    @Published var tokenCount: Int = 0
    @Published var tokensPerSecond: Double = 0
    @Published var streamingStartTime: Date?
    @Published var canContinue: Bool = false
    @Published var errorMessage: String?
    @Published var hasError: Bool = false
    @Published var retryAttempt: Int = 0
    @Published var maxRetries: Int = 3
    
    enum ConnectionState: Equatable {
        case connected
        case connecting
        case streaming
        case retrying(attempt: Int)
        case failed(String) // Use String instead of Error for Equatable conformance
        case offline
        
        var displayText: String {
            switch self {
            case .connected: return "Connected"
            case .connecting: return "Connecting..."
            case .streaming: return "Streaming"
            case .retrying(let attempt): return "Retrying (\(attempt))..."
            case .failed(let message): return "Failed: \(message)"
            case .offline: return "Offline"
            }
        }
        
        var isActive: Bool {
            switch self {
            case .connecting, .streaming, .retrying: return true
            default: return false
            }
        }
    }
    @Published var researchState: ResearchState? = nil
    @Published var isSearching: Bool = false
    @Published var currentSearchResults: [SearchResult]? = nil
    @Published var selectedModel: LLMModel = LLMModel.defaultModel
    @Published var memorySuggestions: [MemorySuggestion] = []
    @Published var showMemorySuggestions: Bool = false
    
    private let aiService = AIService.shared
    private let tokenService = TokenService.shared
    private let cacheService = CacheService.shared
    private let securityService = SecurityService.shared
    private let codeService = CodeService.shared
    private let memoryService = MemoryService.shared
    private let memoryExtractionService = MemoryExtractionService.shared
    private let searchService = SearchService.shared
    private let researchService = ResearchService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let analytics = AnalyticsService.shared
    private var historyService: HistoryService?
    private var modelContext: ModelContext?
    private var _currentChat: Chat?
    private var streamingTask: Task<Void, Never>?
    
    var currentChat: Chat? {
        return _currentChat
    }
    
    func setup(historyService: HistoryService, chat: Chat? = nil, modelContext: ModelContext? = nil) {
        self.historyService = historyService
        self.modelContext = modelContext
        
        if let chat = chat {
            // Используем существующий чат из базы
            self._currentChat = chat
            print("📂 Loading existing chat: \(chat.title), id: \(chat.id)")
            // Загружаем сообщения из существующего чата
            if let chatMessages = chat.messages {
                self.messages = chatMessages.map { chatMessage in
                    Message(
                        id: chatMessage.id,
                        content: chatMessage.content,
                        role: chatMessage.role,
                        timestamp: chatMessage.timestamp,
                        imageData: chatMessage.imageData,
                        isPinned: chatMessage.isPinned,
                        tokenCount: chatMessage.tokenCount,
                        language: chatMessage.language
                    )
                }
            }
            
            // Восстанавливаем режим
            self.currentMode = chat.mode
            
            // Восстанавливаем выбранную модель
            if let model = chat.selectedModel {
                self.selectedModel = model
            } else {
                // Используем модель по умолчанию (OpenRouter)
                self.selectedModel = LLMModel.defaultModel
            }
            
            // Восстанавливаем счетчик токенов
            self.tokenCount = chat.tokenCount
        } else {
            // Создаем новый чат
            initializeNewChat()
        }
        
        updateTokenCount()
    }
    
    private func initializeNewChat() {
        let title = "New Chat"
        let isIncognito = UserDefaults.standard.bool(forKey: "incognitoMode")
        
        // Get default model from settings or use OpenRouter default
        let defaultModel: LLMModel
        if let defaultModelId = UserDefaults.standard.string(forKey: "defaultModelId"),
           let defaultProviderRaw = UserDefaults.standard.string(forKey: "defaultModelProvider"),
           let defaultProvider = LLMProviderType(rawValue: defaultProviderRaw) {
            // Try available models first
            let allAvailable = LLMModel.allModels + CustomModelService.shared.getCustomModels()
            if let model = allAvailable.first(where: { $0.id == defaultModelId && $0.provider == defaultProvider }) {
                defaultModel = model
            } else {
                // Fallback to OpenRouter
                defaultModel = LLMModel.defaultModel
            }
        } else {
            // Use OpenRouter by default
            defaultModel = LLMModel.defaultModel
            // Save as default
            UserDefaults.standard.set(defaultModel.id, forKey: "defaultModelId")
            UserDefaults.standard.set(defaultModel.provider.rawValue, forKey: "defaultModelProvider")
        }
        
        selectedModel = defaultModel
        
        let chat = Chat(title: title, mode: currentMode, isIncognito: isIncognito, model: defaultModel)
        chat.messages = [] // Инициализируем пустой массив
        _currentChat = chat
        
        // НЕ сохраняем пустой чат сразу - сохраним при первом сообщении
        // Это предотвращает создание множества пустых чатов
        print("💾 Initializing new chat: \(chat.title), incognito: \(isIncognito), model: \(defaultModel.displayName) (will save on first message)")
    }
    
    private func updateTokenCount() {
        tokenCount = tokenService.estimateTokensForMessages(messages)
    }
    
    func sendMessage() {
        #if os(iOS)
        let hasImage = selectedImage != nil
        #else
        let hasImage = false
        #endif
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasImage else {
            return
        }
        
        // Проверяем кэш
        let query = inputText
        let userQuery = query // Сохраняем для использования в генерации названия
        if let cached = cacheService.getCachedResponse(query: query, mode: currentMode.rawValue) {
            let cachedMessage = Message(
                content: cached,
                role: .assistant
            )
            messages.append(cachedMessage)
            updateTokenCount()
            return
        }
        
        // Анонимизация данных если включена
        let processedText = securityService.anonymizeData 
            ? securityService.anonymizeText(inputText)
            : inputText
        
        // Автоопределение языка (код или естественный язык)
        let languageDetection = LanguageDetector.detectLanguage(processedText)
        let detectedLanguage: String?
        
        // Сохраняем информацию о языке (код или естественный язык)
        if languageDetection.type == .code {
            detectedLanguage = languageDetection.code
        } else if UserDefaults.standard.bool(forKey: "languageAutoDetectEnabled") {
            // Если включено автоопределение естественного языка
            detectedLanguage = languageDetection.code
        } else {
            detectedLanguage = nil // Не сохраняем язык если отключено
        }
        
        #if os(iOS)
        let imageData = selectedImage != nil ? ImageProcessor.shared.compressImage(selectedImage!) : nil
        #else
        let imageData: Data? = nil
        #endif
        let userMessage = Message(
            content: processedText,
            role: .user,
            imageData: imageData,
            language: detectedLanguage
        )
        
        messages.append(userMessage)
        updateTokenCount()
        
        // Проверяем нужно ли обрезать историю
        if tokenService.shouldTrimMessages(messages) {
            messages = tokenService.trimMessages(messages, keepPinned: true)
            updateTokenCount()
        }
        
        // Сохраняем сообщение в базу
        guard let chat = currentChat else {
            print("⚠️ ERROR: currentChat is nil when sending message")
            return
        }
        
        guard let historyService = self.historyService else {
            print("⚠️ ERROR: historyService is nil when sending message")
            return
        }
        
        // Создаем сообщение
        #if os(iOS)
        let chatMessageImageData = selectedImage != nil ? ImageProcessor.shared.compressImage(selectedImage!) : nil
        #else
        let chatMessageImageData: Data? = nil
        #endif
        let chatMessage = ChatMessage(
            content: processedText,
            role: .user,
            imageData: chatMessageImageData,
            language: detectedLanguage
        )
        
        // Если это первое сообщение, создаем новый чат
        if messages.count == 1 {
            // Создаем новый чат С сообщением
            let preview = processedText.prefix(50)
            let newChat = Chat(
                title: String(preview),
                mode: currentMode,
                isIncognito: UserDefaults.standard.bool(forKey: "incognitoMode"),
                model: selectedModel
            )
            
            // Инициализируем массив сообщений
            newChat.messages = []
            
            // Добавляем сообщение
            newChat.messages?.append(chatMessage)
            chatMessage.chat = newChat
            
            // Устанавливаем даты
            newChat.createdAt = Date()
            newChat.updatedAt = Date()
            
            _currentChat = newChat
            
            print("💾 Saving NEW chat with first message: '\(newChat.title)'")
            print("💾 Chat ID: \(newChat.id), messages: \(newChat.messages?.count ?? 0)")
            
            // Сохраняем чат С сообщением
            historyService.saveChat(newChat)
        } else {
            // Обновляем существующий чат
            let preview = processedText.prefix(50)
            chat.title = String(preview)
            
            // Инициализируем массив сообщений
            if chat.messages == nil {
                chat.messages = []
            }
            
            // Добавляем сообщение
            chat.messages?.append(chatMessage)
            chatMessage.chat = chat
            chat.updatedAt = Date()
            
            print("💾 Updating existing chat: '\(chat.title)'")
            historyService.updateChat(chat)
            
            // Также сохраняем сообщение отдельно для надежности
            historyService.addMessage(chatMessage, to: chat)
        }
        
        #if os(iOS)
        let imageToSend = selectedImage
        selectedImage = nil
        let imageDataToSend: Data? = imageToSend != nil ? ImageProcessor.shared.compressImage(imageToSend!) : nil
        #else
        let imageDataToSend: Data? = nil
        #endif
        inputText = ""
        
        // Check network connection
        guard networkMonitor.isConnected else {
            connectionState = .offline
            errorMessage = "No internet connection. Please check your network settings."
            hasError = true
            return
        }
        
        isLoading = true
        isStreaming = true
        streamingText = ""
        streamingStartTime = Date()
        tokensPerSecond = 0
        canContinue = false
        connectionState = .connecting
        retryAttempt = 0
        
        streamingTask = Task {
            do {
                var assistantMessage = Message(
                    content: "",
                    role: .assistant,
                    language: nil,
                    searchResults: nil
                )
                messages.append(assistantMessage)
                
                // Загружаем только последние N сообщений для контекста
                let contextMessages = tokenService.trimMessages(messages.dropLast(), keepPinned: true)
                
                // Загружаем контекст памяти
                let memoryContext = modelContext.map { memoryService.buildMemoryContext(context: $0) } ?? ""
                
                // Определяем, нужен ли веб-поиск (для Research Mode и запросов, требующих актуальной информации)
                var webSearchContext: String? = nil
                var searchResults: [SearchResult] = []
                
                if currentMode == .research || researchService.needsWebSearch(query: query) {
                    researchState = .researching
                    isSearching = true
                    
                    do {
                        let searchQuery = researchService.buildSearchQuery(from: query)
                        let searchResponse = try await searchService.search(query: searchQuery, limit: 5)
                        
                        if !searchResponse.results.isEmpty {
                            searchResults = searchResponse.results
                            currentSearchResults = searchResponse.results
                            webSearchContext = researchService.formatSearchResults(searchResponse.results)
                            print("✅ Web search completed: found \(searchResponse.results.count) results")
                        } else {
                            print("⚠️ Web search returned no results")
                            currentSearchResults = nil
                        }
                        
                        isSearching = false
                    } catch {
                        print("⚠️ Web search error: \(error.localizedDescription)")
                        isSearching = false
                        
                        // Показываем предупреждение только если это не отсутствие API ключа
                        if let searchServiceError = error as? SearchServiceError {
                            switch searchServiceError {
                            case .missingAPIKey:
                                // Не показываем ошибку, просто продолжаем без поиска
                                break
                            default:
                                // Для других ошибок можно показать уведомление, но не блокируем ответ
                                print("⚠️ Web search failed: \(searchServiceError.localizedDescription)")
                            }
                        }
                        // Продолжаем без веб-поиска
                    }
                }
                
                // Устанавливаем состояние анализа для Research Mode
                if currentMode == .research {
                    researchState = .analyzing
                }
                
                connectionState = .streaming
                let requestStartTime = Date()
                
                analytics.track(name: "message_sent", properties: [
                    "mode": currentMode.rawValue,
                    "model": selectedModel.id,
                    "provider": selectedModel.provider.rawValue,
                    "has_image": imageDataToSend != nil
                ])
                
                let stream = try await aiService.sendMessage(
                    messages: contextMessages,
                    mode: currentMode,
                    model: selectedModel,
                    imageData: imageDataToSend,
                    memoryContext: memoryContext,
                    webSearchContext: webSearchContext
                )
                
                // Устанавливаем состояние синтеза для Research Mode
                if currentMode == .research {
                    researchState = .synthesizing
                }
                
                var chunkCount = 0
                var lastHapticTime: Date?
                let hapticInterval: TimeInterval = 0.3 // Оптимизировано: haptic каждые 300ms (было 100ms)
                
                for try await chunk in stream {
                    // Update connection state to streaming
                    if connectionState != .streaming {
                        connectionState = .streaming
                    }
                    streamingText += chunk
                    chunkCount += 1
                    
                    // Оптимизированный haptic feedback - реже для лучшей производительности
                    #if os(iOS)
                    let now = Date()
                    if lastHapticTime == nil || now.timeIntervalSince(lastHapticTime!) >= hapticInterval {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        lastHapticTime = now
                    }
                    #endif
                    
                    // Обновляем скорость генерации
                    if let startTime = streamingStartTime {
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed > 0 {
                            let estimatedTokens = tokenService.estimateTokens(text: streamingText)
                            tokensPerSecond = Double(estimatedTokens) / elapsed
                        }
                    }
                    
                    let messageTokens = tokenService.estimateTokens(text: streamingText)
                    
                    // Определяем язык при накоплении текста
                    let languageDetection = LanguageDetector.detectLanguage(streamingText)
                    let detectedLanguage: String?
                    if languageDetection.type == .code {
                        detectedLanguage = languageDetection.code
                    } else if UserDefaults.standard.bool(forKey: "languageAutoDetectEnabled") {
                        detectedLanguage = languageDetection.code
                    } else {
                        detectedLanguage = nil
                    }
                    
                    assistantMessage = Message(
                        id: assistantMessage.id,
                        content: streamingText,
                        role: .assistant,
                        timestamp: assistantMessage.timestamp,
                        tokenCount: messageTokens,
                        language: detectedLanguage,
                        tokensPerSecond: tokensPerSecond,
                        searchResults: searchResults.isEmpty ? nil : searchResults
                    )
                    messages[messages.count - 1] = assistantMessage
                }
                
                // Сохраняем в кэш
                cacheService.cacheResponse(query: query, response: streamingText, mode: currentMode.rawValue)
                
                // Track successful response
                let responseTime = Date().timeIntervalSince(requestStartTime)
                analytics.track(name: "llm_response_complete", properties: [
                    "mode": currentMode.rawValue,
                    "model": selectedModel.id,
                    "provider": selectedModel.provider.rawValue,
                    "duration": responseTime,
                    "token_count": tokenCount
                ])
                
                // Сохраняем финальное сообщение
                guard let chat = currentChat else {
                    print("⚠️ ERROR: currentChat is nil when saving assistant message")
                    return
                }
                
                guard let historyService = self.historyService else {
                    print("⚠️ ERROR: historyService is nil when saving assistant message")
                    return
                }
                
                // Определяем язык для ответа ассистента
                let assistantLanguageDetection = LanguageDetector.detectLanguage(streamingText)
                let assistantLanguage: String?
                if assistantLanguageDetection.type == .code {
                    assistantLanguage = assistantLanguageDetection.code
                } else if UserDefaults.standard.bool(forKey: "languageAutoDetectEnabled") {
                    assistantLanguage = assistantLanguageDetection.code
                } else {
                    assistantLanguage = nil
                }
                
                let assistantChatMessage = ChatMessage(
                    content: streamingText,
                    role: .assistant,
                    tokenCount: assistantMessage.tokenCount,
                    language: assistantLanguage
                )
                
                        print("💾 Saving assistant message to chat: '\(chat.title)'")
                        historyService.addMessage(assistantChatMessage, to: chat)
                        chat.tokenCount = tokenCount
                        chat.updatedAt = Date() // Обновляем дату обновления
                        
                        // Генерируем название чата если это первый ответ AI и название еще дефолтное
                        let isDefaultTitle = chat.title.count <= 50 && (chat.title == "New Chat" || chat.title == userQuery.prefix(50))
                        if isDefaultTitle && messages.count >= 2 {
                            // Генерируем название асинхронно, не блокируя UI
                            Task {
                                if let generatedTitle = await ChatTitleService.shared.generateTitle(for: messages, mode: currentMode) {
                                    await MainActor.run {
                                        chat.title = generatedTitle
                                        historyService.updateChat(chat)
                                        print("✅ Generated chat title: '\(generatedTitle)'")
                                    }
                                } else {
                                    // Если не удалось сгенерировать через AI, используем простое название
                                    await MainActor.run {
                                        let simpleTitle = ChatTitleService.shared.generateSimpleTitle(from: userQuery)
                                        chat.title = simpleTitle
                                        historyService.updateChat(chat)
                                        print("✅ Using simple chat title: '\(simpleTitle)'")
                                    }
                                }
                            }
                        }
                        
                        historyService.updateChat(chat)
                        print("💾 Chat updated. Total messages: \(chat.messages?.count ?? 0)")
                        
                        // Убрано дублирующее сохранение - updateChat уже сохраняет
                
                // Отправляем уведомление о завершении
                NotificationService.shared.scheduleCompletionNotification(chatTitle: chat.title)
                
                // Получаем предложения памяти от AI (асинхронно, не блокируя UI)
                if let context = modelContext {
                    Task {
                        // Небольшая задержка перед анализом (чтобы пользователь увидел ответ)
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 секунды
                        
                        // Получаем AI предложения
                        let suggestions = await memoryExtractionService.suggestMemories(from: messages, using: aiService)
                        
                        // Показываем предложения пользователю
                        if !suggestions.isEmpty {
                            await MainActor.run {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    self.memorySuggestions = suggestions
                                    self.showMemorySuggestions = true
                                }
                            }
                        }
                        
                        // Также выполняем автоматическое извлечение (в фоне, без предложений)
                        await extractAndSaveMemories(context: context, messages: messages)
                    }
                }
                
                isStreaming = false
                isLoading = false
                canContinue = false
                isSearching = false
                
                // Сбрасываем состояние исследования после завершения
                if currentMode == .research {
                    researchState = .complete
                    // Сбрасываем через 2 секунды
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if researchState == .complete {
                            researchState = nil
                        }
                    }
                }
                
                // Сбрасываем результаты поиска через 5 секунд после завершения
                if currentSearchResults != nil {
                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        currentSearchResults = nil
                    }
                }
                
                updateTokenCount()
            } catch {
                isStreaming = false
                isLoading = false
                canContinue = false
                
                // Check if error is retryable
                let retryService = LLMRetryService.shared
                let isRetryable = retryService.isRetryable(error)
                
                // Update connection state
                if !networkMonitor.isConnected {
                    connectionState = .offline
                    errorMessage = "No internet connection. Please check your network settings."
                } else if isRetryable && retryAttempt < maxRetries {
                    retryAttempt += 1
                    connectionState = .retrying(attempt: retryAttempt)
                    errorMessage = "Retrying request... (\(retryAttempt)/\(maxRetries))"
                    
                    // Auto-retry after delay
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(2_000_000_000)) // 2 seconds
                        await sendMessage()
                    }
                    return
                } else {
                    connectionState = .failed(error.localizedDescription)
                    errorMessage = error.localizedDescription
                    
                    // Track error
                    analytics.track(name: "llm_error", properties: [
                        "mode": currentMode.rawValue,
                        "model": selectedModel.id,
                        "provider": selectedModel.provider.rawValue,
                        "error": error.localizedDescription,
                        "retry_attempt": retryAttempt
                    ])
                }
                
                // Удаляем пустое сообщение ассистента, если оно было создано
                if let lastMessage = messages.last, lastMessage.role == .assistant, lastMessage.content.isEmpty {
                    messages.removeLast()
                }
                
                // Устанавливаем ошибку
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.hasError = true
                }
                
                // Показываем ошибку в сообщении
                let errorMessage = Message(
                    content: "❌ Ошибка: \(error.localizedDescription)",
                    role: .assistant
                )
                messages.append(errorMessage)
            }
        }
    }
    
    func continueGeneration() {
        guard !streamingText.isEmpty else { return }
        
        canContinue = true
        isStreaming = true
        let previousText = streamingText
        
        streamingTask = Task {
            do {
                let contextMessages = tokenService.trimMessages(messages.dropLast(), keepPinned: true)
                let continueMessage = Message(content: "Продолжи с того места где остановился", role: .user)
                
                let stream = try await aiService.sendMessage(
                    messages: contextMessages + [continueMessage],
                    mode: currentMode,
                    imageData: nil
                )
                
                var lastHapticTime: Date?
                let hapticInterval: TimeInterval = 0.1
                var accumulatedText = previousText
                
                for try await chunk in stream {
                    accumulatedText += chunk
                    streamingText = accumulatedText
                    
                    // Haptic feedback
                    #if os(iOS)
                    let now = Date()
                    if lastHapticTime == nil || now.timeIntervalSince(lastHapticTime!) >= hapticInterval {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        lastHapticTime = now
                    }
                    #endif
                    
                    let messageTokens = tokenService.estimateTokens(text: accumulatedText)
                    
                    if let lastMessage = messages.last, lastMessage.role == .assistant {
                        let updatedMessage = Message(
                            id: lastMessage.id,
                            content: accumulatedText,
                            role: .assistant,
                            timestamp: lastMessage.timestamp,
                            tokenCount: messageTokens
                        )
                        messages[messages.count - 1] = updatedMessage
                    }
                }
                
                isStreaming = false
                canContinue = false
                updateTokenCount()
            } catch {
                isStreaming = false
                canContinue = false
            }
        }
    }
    
    func togglePinMessage(_ message: Message) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updated = message
            updated.isPinned = !message.isPinned
            messages[index] = updated
        }
    }
    
    func changeMode(_ newMode: AIMode) {
        guard newMode != currentMode else { return }
        
        // Сохраняем текущий чат
        if let chat = currentChat, !messages.isEmpty {
            chat.selectedModel = selectedModel
            historyService?.updateChat(chat)
        }
        
        // Создаем новый чат для нового режима
        currentMode = newMode
        messages = []
        tokenCount = 0
        initializeNewChat()
    }
    
    func changeModel(_ newModel: LLMModel) {
        selectedModel = newModel
        
        // Сохраняем модель в текущий чат
        if let chat = currentChat {
            chat.selectedModel = newModel
            historyService?.updateChat(chat)
        }
    }
    
    func createNewChat() {
        // Сохраняем текущий чат если есть сообщения
        if let chat = currentChat, !messages.isEmpty {
            historyService?.updateChat(chat)
        }
        
        // Очищаем состояние
        messages = []
        inputText = ""
        #if os(iOS)
        selectedImage = nil
        #endif
        tokenCount = 0
        streamingText = ""
        isStreaming = false
        isLoading = false
        canContinue = false
        tokensPerSecond = 0
        
        // Отменяем текущий стриминг
        cancelStreaming()
        
        // Создаем новый чат (НЕ сохраняем пустой чат)
        initializeNewChat()
    }
    
    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        isLoading = false
        canContinue = false
    }
    
    func clearError() {
        errorMessage = nil
        hasError = false
    }
    
    private func extractAndSaveMemories(context: ModelContext, messages: [Message]) async {
        // Извлекаем память из диалога (с автоматической оценкой важности)
        let extractedMemories = await memoryExtractionService.extractMemories(from: messages, using: aiService)
        
        // Сохраняем извлеченную память (importance уже рассчитан)
        for memory in extractedMemories {
            memoryService.saveMemory(
                context: context,
                type: memory.type,
                key: memory.key,
                content: memory.content,
                importance: memory.importance
            )
        }
        
        if !extractedMemories.isEmpty {
            print("💾 Extracted and saved \(extractedMemories.count) memory items with importance scores")
        }
        
        // Периодическое обслуживание памяти (очистка и переоценка)
        // Выполняем не каждый раз, а с вероятностью 10%
        if Int.random(in: 1...10) == 1 {
            memoryService.performMemoryMaintenance(context: context)
        }
    }
    
    deinit {
        streamingTask?.cancel()
        streamingTask = nil
    }
}
