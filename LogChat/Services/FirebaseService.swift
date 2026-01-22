//
//  FirebaseService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData
import Combine
#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

typealias Timestamp = FirebaseFirestore.Timestamp
typealias ListenerRegistration = FirebaseFirestore.ListenerRegistration
#endif

/// Сервис для синхронизации данных через Firebase Firestore
@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isFirebaseAvailable: Bool = false
    
    #if canImport(FirebaseCore)
    private var db: Firestore?
    private var cancellables = Set<AnyCancellable>()
    private var listeners: [ListenerRegistration] = []
    
    // Collection names
    private let memoriesCollection = "memories"
    private let projectsCollection = "projects"
    private let chatsCollection = "chats"
    private let messagesCollection = "messages"
    private let settingsCollection = "settings"
    #endif
    
    private init() {
        checkFirebaseAvailability()
        
        // Настраиваем слушатели после небольшой задержки, чтобы Firebase успел инициализироваться
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupRealtimeListeners()
        }
    }
    
    deinit {
        #if canImport(FirebaseCore)
        // Отписываемся от всех слушателей
        listeners.forEach { $0.remove() }
        #endif
    }
    
    // MARK: - Firebase Availability
    
    private func checkFirebaseAvailability() {
        // Проверяем доступность Firebase SDK
        #if canImport(FirebaseCore)
        print("✅ Firebase SDK is available")
        
        // Проверяем, инициализирован ли Firebase
        // Firebase инициализируется в AppDelegate, но это может произойти позже
        // Поэтому проверяем асинхронно
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if FirebaseApp.app() != nil {
                self.isFirebaseAvailable = true
                self.db = Firestore.firestore()
                print("✅ Firebase initialized successfully")
            } else {
                self.isFirebaseAvailable = false
                print("⚠️ Firebase SDK installed but not initialized yet.")
                print("   This is normal on first launch - Firebase will initialize via AppDelegate")
                print("   If this persists, check:")
                print("   1. GoogleService-Info.plist is added to project (see FIREBASE_SETUP.md)")
                print("   2. AppDelegate is properly configured in LogChatApp.swift")
            }
        }
        #else
        // Firebase SDK не найден - возможно не добавлен в target или не пересобран проект
        isFirebaseAvailable = false
        print("⚠️ Firebase SDK not found by compiler.")
        print("   ⚠️ Пакет добавлен в проект, но НЕ добавлен в target 'LogChat'!")
        print("   📋 Решение:")
        print("   1. В диалоге добавления пакета выберите target 'LogChat'")
        print("   2. Или: Project > Target LogChat > General > Frameworks > Добавьте FirebaseCore, FirebaseFirestore")
        print("   3. Product > Clean Build Folder (⇧⌘K)")
        print("   4. Product > Build (⌘B)")
        print("   📚 Подробности: FIX_FIREBASE_TARGET.md")
        #endif
    }
    
    // MARK: - Memory Sync
    
    /// Синхронизирует память с Firebase
    func syncMemory(context: ModelContext) async throws {
        #if canImport(FirebaseCore)
        guard isFirebaseAvailable, let db = db else {
            throw FirebaseError.notInitialized
        }
        
        syncStatus = .syncing
        
        do {
            // Загружаем локальную память
            let localMemories = try context.fetch(FetchDescriptor<MemoryItem>())
            
            // Загружаем память из Firebase
            let firebaseMemories = try await fetchFirebaseMemories(db: db)
            
            // Синхронизируем: объединяем и обновляем
            try await mergeMemories(local: localMemories, firebase: firebaseMemories, context: context)
            
            // Отправляем обновления в Firebase
            try await pushMemoriesToFirebase(memories: localMemories, db: db)
            
            syncStatus = .success
            lastSyncDate = Date()
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
        #else
        throw FirebaseError.notInitialized
        #endif
    }
    
    #if canImport(FirebaseCore)
    /// Загружает память из Firebase
    private func fetchFirebaseMemories(db: Firestore) async throws -> [[String: Any]] {
        let snapshot = try await db.collection(memoriesCollection).getDocuments()
        
        var memories: [[String: Any]] = []
        for document in snapshot.documents {
            var data = document.data()
            data["id"] = document.documentID
            memories.append(data)
        }
        
        return memories
    }
    
    /// Объединяет локальную и Firebase память
    private func mergeMemories(local: [MemoryItem], firebase: [[String: Any]], context: ModelContext) async throws {
        // Создаем словарь локальных записей по ID
        var localDict: [UUID: MemoryItem] = [:]
        for memory in local {
            localDict[memory.id] = memory
        }
        
        // Обрабатываем Firebase записи
        for firebaseData in firebase {
            guard let idString = firebaseData["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }
            
            if let localMemory = localDict[id] {
                // Обновляем локальную запись, если Firebase новее
                if let firebaseUpdated = firebaseData["updatedAt"] as? Timestamp,
                   firebaseUpdated.dateValue() > localMemory.updatedAt {
                    updateMemoryFromFirebase(localMemory, data: firebaseData)
                }
            } else {
                // Создаем новую локальную запись из Firebase
                createMemoryFromFirebase(data: firebaseData, context: context)
            }
        }
        
        try context.save()
    }
    
    /// Обновляет память из Firebase данных
    private func updateMemoryFromFirebase(_ memory: MemoryItem, data: [String: Any]) {
        if let typeString = data["type"] as? String {
            memory.type = typeString
        }
        if let key = data["key"] as? String {
            memory.key = key
        }
        if let content = data["content"] as? String {
            memory.content = content
        }
        if let importance = data["importance"] as? Int {
            memory.importance = importance
        }
        if let updatedAt = data["updatedAt"] as? Timestamp {
            memory.updatedAt = updatedAt.dateValue()
        }
        if let lastUsedAt = data["lastUsedAt"] as? Timestamp {
            memory.lastUsedAt = lastUsedAt.dateValue()
        }
        if let usageCount = data["usageCount"] as? Int {
            memory.usageCount = usageCount
        }
    }
    
    /// Создает память из Firebase данных
    private func createMemoryFromFirebase(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let typeString = data["type"] as? String,
              let type = MemoryType(rawValue: typeString),
              let key = data["key"] as? String,
              let content = data["content"] as? String else {
            return
        }
        
        let importance = data["importance"] as? Int ?? 5
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastUsedAt = (data["lastUsedAt"] as? Timestamp)?.dateValue()
        let usageCount = data["usageCount"] as? Int ?? 0
        
        let memory = MemoryItem(
            id: id,
            type: type,
            key: key,
            content: content,
            importance: importance,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt,
            usageCount: usageCount
        )
        
        context.insert(memory)
    }
    
    /// Отправляет память в Firebase
    private func pushMemoriesToFirebase(memories: [MemoryItem], db: Firestore) async throws {
        let batch = db.batch()
        
        for memory in memories {
            let docRef = db.collection(memoriesCollection).document(memory.id.uuidString)
            
            batch.setData([
                "id": memory.id.uuidString,
                "type": memory.type,
                "key": memory.key,
                "content": memory.content,
                "importance": memory.importance,
                "createdAt": Timestamp(date: memory.createdAt),
                "updatedAt": Timestamp(date: memory.updatedAt),
                "lastUsedAt": memory.lastUsedAt != nil ? Timestamp(date: memory.lastUsedAt!) : NSNull(),
                "usageCount": memory.usageCount
            ], forDocument: docRef, merge: true)
        }
        
        try await batch.commit()
    }
    #endif
    
    // MARK: - Chat Sync
    
    /// Синхронизирует чаты с Firebase
    func syncChats(context: ModelContext) async throws {
        #if canImport(FirebaseCore)
        guard isFirebaseAvailable, let db = db else {
            throw FirebaseError.notInitialized
        }
        
        syncStatus = .syncing
        
        do {
            // Загружаем локальные чаты
            let localChats = try context.fetch(FetchDescriptor<Chat>(
                sortBy: [SortDescriptor(\Chat.updatedAt, order: .reverse)]
            ))
            
            // Загружаем чаты из Firebase
            let firebaseChats = try await fetchFirebaseChats(db: db)
            
            // Синхронизируем: объединяем и обновляем
            try await mergeChats(local: localChats, firebase: firebaseChats, context: context)
            
            // Отправляем обновления в Firebase
            try await pushChatsToFirebase(chats: localChats, db: db)
            
            syncStatus = .success
            lastSyncDate = Date()
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
        #else
        throw FirebaseError.notInitialized
        #endif
    }
    
    #if canImport(FirebaseCore)
    /// Загружает чаты из Firebase
    private func fetchFirebaseChats(db: Firestore) async throws -> [[String: Any]] {
        let snapshot = try await db.collection(chatsCollection).getDocuments()
        
        var chats: [[String: Any]] = []
        for document in snapshot.documents {
            var data = document.data()
            data["id"] = document.documentID
            chats.append(data)
        }
        
        return chats
    }
    
    /// Объединяет локальные и Firebase чаты
    private func mergeChats(local: [Chat], firebase: [[String: Any]], context: ModelContext) async throws {
        var localDict: [UUID: Chat] = [:]
        for chat in local {
            localDict[chat.id] = chat
        }
        
        // Обрабатываем Firebase чаты
        for firebaseData in firebase {
            guard let idString = firebaseData["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }
            
            if let localChat = localDict[id] {
                // Обновляем локальный чат, если Firebase новее
                if let firebaseUpdated = firebaseData["updatedAt"] as? Timestamp,
                   firebaseUpdated.dateValue() > localChat.updatedAt {
                    updateChatFromFirebase(localChat, data: firebaseData)
                }
            } else {
                // Создаем новый локальный чат из Firebase
                createChatFromFirebase(data: firebaseData, context: context)
            }
        }
        
        try context.save()
    }
    
    /// Обновляет чат из Firebase данных
    private func updateChatFromFirebase(_ chat: Chat, data: [String: Any]) {
        if let title = data["title"] as? String {
            chat.title = title
        }
        if let modeRawValue = data["modeRawValue"] as? String {
            chat.modeRawValue = modeRawValue
        }
        if let tags = data["tags"] as? [String] {
            chat.tags = tags
        }
        if let isPinned = data["isPinned"] as? Bool {
            chat.isPinned = isPinned
        }
        if let summary = data["summary"] as? String {
            chat.summary = summary
        }
        if let tokenCount = data["tokenCount"] as? Int {
            chat.tokenCount = tokenCount
        }
        if let isIncognito = data["isIncognito"] as? Bool {
            chat.isIncognito = isIncognito
        }
        if let updatedAt = data["updatedAt"] as? Timestamp {
            chat.updatedAt = updatedAt.dateValue()
        }
    }
    
    /// Создает чат из Firebase данных
    private func createChatFromFirebase(data: [String: Any], context: ModelContext) {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = data["title"] as? String,
              let modeRawValue = data["modeRawValue"] as? String else {
            return
        }
        
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let tags = data["tags"] as? [String] ?? []
        let isPinned = data["isPinned"] as? Bool ?? false
        let summary = data["summary"] as? String
        let tokenCount = data["tokenCount"] as? Int ?? 0
        let isIncognito = data["isIncognito"] as? Bool ?? false
        
        let chat = Chat(
            id: id,
            title: title,
            mode: AIMode(rawValue: modeRawValue) ?? .daily,
            createdAt: createdAt,
            updatedAt: updatedAt,
            tags: tags,
            isPinned: isPinned,
            summary: summary,
            tokenCount: tokenCount,
            isIncognito: isIncognito
        )
        
        context.insert(chat)
    }
    
    /// Отправляет чаты в Firebase
    private func pushChatsToFirebase(chats: [Chat], db: Firestore) async throws {
        let batch = db.batch()
        
        for chat in chats {
            let chatRef = db.collection(chatsCollection).document(chat.id.uuidString)
            
            batch.setData([
                "id": chat.id.uuidString,
                "title": chat.title,
                "modeRawValue": chat.modeRawValue,
                "createdAt": Timestamp(date: chat.createdAt),
                "updatedAt": Timestamp(date: chat.updatedAt),
                "tags": chat.tags,
                "isPinned": chat.isPinned,
                "summary": chat.summary ?? NSNull(),
                "tokenCount": chat.tokenCount,
                "isIncognito": chat.isIncognito
            ], forDocument: chatRef, merge: true)
            
            // Синхронизируем сообщения чата
            if let messages = chat.messages {
                try await pushMessagesToFirebase(messages: messages, chatId: chat.id, db: db)
            }
        }
        
        try await batch.commit()
    }
    
    /// Отправляет сообщения в Firebase
    private func pushMessagesToFirebase(messages: [ChatMessage], chatId: UUID, db: Firestore) async throws {
        let batch = db.batch()
        
        for message in messages {
            let messageRef = db.collection(messagesCollection).document(message.id.uuidString)
            
            var messageData: [String: Any] = [
                "id": message.id.uuidString,
                "chatId": chatId.uuidString,
                "content": message.content,
                "roleRawValue": message.roleRawValue,
                "timestamp": Timestamp(date: message.timestamp),
                "isPinned": message.isPinned,
                "tokenCount": message.tokenCount,
                "language": message.language ?? NSNull()
            ]
            
            // Изображения сохраняем как base64 (или можно использовать Firebase Storage)
            if let imageData = message.imageData {
                messageData["imageData"] = imageData.base64EncodedString()
            }
            
            batch.setData(messageData, forDocument: messageRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    /// Загружает сообщения из Firebase
    func fetchMessagesForChat(chatId: UUID, context: ModelContext) async throws {
        #if canImport(FirebaseCore)
        guard isFirebaseAvailable, let db = db else {
            throw FirebaseError.notInitialized
        }
        
        let snapshot = try await db.collection(messagesCollection)
            .whereField("chatId", isEqualTo: chatId.uuidString)
            .order(by: "timestamp")
            .getDocuments()
        
        guard let chat = try? context.fetch(FetchDescriptor<Chat>(
            predicate: #Predicate<Chat> { $0.id == chatId }
        )).first else {
            return
        }
        
        for document in snapshot.documents {
            let data = document.data()
            guard let messageIdString = data["id"] as? String,
                  let messageId = UUID(uuidString: messageIdString),
                  let content = data["content"] as? String,
                  let roleRawValue = data["roleRawValue"] as? String else {
                continue
            }
            
            // Проверяем, есть ли уже такое сообщение
            let existingMessages = chat.messages ?? []
            if existingMessages.contains(where: { $0.id == messageId }) {
                continue
            }
            
            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let isPinned = data["isPinned"] as? Bool ?? false
            let tokenCount = data["tokenCount"] as? Int ?? 0
            let language = data["language"] as? String
            
            var imageData: Data? = nil
            if let imageBase64 = data["imageData"] as? String {
                imageData = Data(base64Encoded: imageBase64)
            }
            
            let message = ChatMessage(
                id: messageId,
                content: content,
                role: MessageRole(rawValue: roleRawValue) ?? .user,
                timestamp: timestamp,
                imageData: imageData,
                isPinned: isPinned,
                tokenCount: tokenCount,
                language: language
            )
            
            message.chat = chat
            context.insert(message)
        }
        
        try context.save()
        #endif
    }
    #endif
    
    // MARK: - Settings Sync
    
    /// Синхронизирует настройки с Firebase
    func syncSettings() async throws {
        #if canImport(FirebaseCore)
        guard isFirebaseAvailable, let db = db else {
            throw FirebaseError.notInitialized
        }
        
        // Загружаем настройки из Firebase
        let settingsDoc = try await db.collection(settingsCollection).document("userSettings").getDocument()
        
        if let data = settingsDoc.data() {
            // Применяем настройки к UserDefaults
            if let apiKey = data["openRouterAPIKey"] as? String {
                UserDefaults.standard.set(apiKey, forKey: "openRouterAPIKey")
            }
            if let searchAPIKey = data["searchAPIKey"] as? String {
                UserDefaults.standard.set(searchAPIKey, forKey: "searchAPIKey")
            }
            if let searchProvider = data["searchProvider"] as? String {
                UserDefaults.standard.set(searchProvider, forKey: "searchProvider")
            }
            if let contextTokenLimit = data["contextTokenLimit"] as? Int {
                UserDefaults.standard.set(contextTokenLimit, forKey: "contextTokenLimit")
            }
            if let biometricEnabled = data["biometricEnabled"] as? Bool {
                UserDefaults.standard.set(biometricEnabled, forKey: "biometricEnabled")
            }
            if let anonymizeData = data["anonymizeData"] as? Bool {
                UserDefaults.standard.set(anonymizeData, forKey: "anonymizeData")
            }
            if let incognitoMode = data["incognitoMode"] as? Bool {
                UserDefaults.standard.set(incognitoMode, forKey: "incognitoMode")
            }
            if let appTheme = data["appTheme"] as? String {
                UserDefaults.standard.set(appTheme, forKey: "appTheme")
            }
            if let fontSize = data["fontSize"] as? Double {
                UserDefaults.standard.set(fontSize, forKey: "fontSize")
            }
            if let sidebarWidth = data["sidebarWidth"] as? Double {
                UserDefaults.standard.set(sidebarWidth, forKey: "sidebarWidth")
            }
            if let panelSpacing = data["panelSpacing"] as? Double {
                UserDefaults.standard.set(panelSpacing, forKey: "panelSpacing")
            }
        }
        
        // Отправляем текущие настройки в Firebase
        try await pushSettingsToFirebase(db: db)
        #else
        throw FirebaseError.notInitialized
        #endif
    }
    
    #if canImport(FirebaseCore)
    /// Отправляет настройки в Firebase
    private func pushSettingsToFirebase(db: Firestore) async throws {
        let settings: [String: Any] = [
            "openRouterAPIKey": UserDefaults.standard.string(forKey: "openRouterAPIKey") ?? "",
            "searchAPIKey": UserDefaults.standard.string(forKey: "searchAPIKey") ?? "",
            "searchProvider": UserDefaults.standard.string(forKey: "searchProvider") ?? "serper",
            "contextTokenLimit": UserDefaults.standard.integer(forKey: "contextTokenLimit"),
            "biometricEnabled": UserDefaults.standard.bool(forKey: "biometricEnabled"),
            "anonymizeData": UserDefaults.standard.bool(forKey: "anonymizeData"),
            "incognitoMode": UserDefaults.standard.bool(forKey: "incognitoMode"),
            "appTheme": UserDefaults.standard.string(forKey: "appTheme") ?? "auto",
            "fontSize": UserDefaults.standard.double(forKey: "fontSize"),
            "sidebarWidth": UserDefaults.standard.double(forKey: "sidebarWidth"),
            "panelSpacing": UserDefaults.standard.double(forKey: "panelSpacing"),
            "lastUpdated": Timestamp(date: Date())
        ]
        
        try await db.collection(settingsCollection).document("userSettings").setData(settings, merge: true)
    }
    #endif
    
    // MARK: - Project Sync
    
    /// Синхронизирует проекты с Firebase
    func syncProjects(context: ModelContext) async throws {
        #if canImport(FirebaseCore)
        guard isFirebaseAvailable, let db = db else {
            throw FirebaseError.notInitialized
        }
        
        let localProjects = try context.fetch(FetchDescriptor<Project>())
        
        // Отправляем проекты в Firebase
        let batch = db.batch()
        for project in localProjects {
            let projectRef = db.collection(projectsCollection).document(project.id.uuidString)
            
            batch.setData([
                "id": project.id.uuidString,
                "name": project.name,
                "projectDescription": project.projectDescription ?? NSNull(),
                "status": project.status,
                "priority": project.priority,
                "createdAt": Timestamp(date: project.createdAt),
                "updatedAt": Timestamp(date: project.updatedAt),
                "tags": project.tags,
                "progress": project.progress,
                "notes": project.notes ?? NSNull(),
                "lastAnalyzedAt": project.lastAnalyzedAt != nil ? Timestamp(date: project.lastAnalyzedAt!) : NSNull()
            ], forDocument: projectRef, merge: true)
        }
        
        try await batch.commit()
        print("💾 Synced \(localProjects.count) projects to Firebase")
        #else
        throw FirebaseError.notInitialized
        #endif
    }
    
    // MARK: - Realtime Listeners
    
    /// Настраивает слушатели изменений в реальном времени
    private func setupRealtimeListeners() {
        #if canImport(FirebaseCore)
        // Проверяем еще раз, так как Firebase может инициализироваться асинхронно
        guard let firebaseApp = FirebaseApp.app(), let db = db else {
            print("ℹ️ Firebase not ready yet for realtime listeners, will retry later")
            return
        }
        
        isFirebaseAvailable = true
        print("✅ Firebase ready for realtime listeners")
        
        // Слушатель изменений настроек
        let settingsListener = db.collection(settingsCollection).document("userSettings")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data(), error == nil else { return }
                
                Task { @MainActor in
                    // Применяем изменения настроек
                    if let apiKey = data["openRouterAPIKey"] as? String, !apiKey.isEmpty {
                        UserDefaults.standard.set(apiKey, forKey: "openRouterAPIKey")
                        AIService.shared.updateAPIKey(apiKey)
                    }
                    if let searchAPIKey = data["searchAPIKey"] as? String {
                        UserDefaults.standard.set(searchAPIKey, forKey: "searchAPIKey")
                    }
                    if let searchProvider = data["searchProvider"] as? String {
                        UserDefaults.standard.set(searchProvider, forKey: "searchProvider")
                    }
                    // Другие настройки...
                }
            }
        
        listeners.append(settingsListener)
        #endif
    }
    
    // MARK: - Full Sync
    
    /// Полная синхронизация всех данных
    func syncAll(context: ModelContext) async {
        #if canImport(FirebaseCore)
        // Проверяем доступность Firebase еще раз
        guard let firebaseApp = FirebaseApp.app(), let db = self.db else {
            syncStatus = .error("Firebase не инициализирован. Проверьте GoogleService-Info.plist")
            print("⚠️ Firebase not initialized. Check:")
            print("   1. GoogleService-Info.plist is in project")
            print("   2. AppDelegate calls FirebaseApp.configure()")
            return
        }
        
        // Обновляем состояние
        isFirebaseAvailable = true
        self.db = db
        
        syncStatus = .syncing
        
        do {
            // Синхронизируем настройки (API ключи и т.д.)
            try await syncSettings()
            
            // Синхронизируем память
            try await syncMemory(context: context)
            
            // Синхронизируем чаты и сообщения
            try await syncChats(context: context)
            
            // Синхронизируем проекты
            try await syncProjects(context: context)
            
            syncStatus = .success
            lastSyncDate = Date()
            
            print("✅ Full sync completed successfully")
        } catch {
            syncStatus = .error(error.localizedDescription)
            print("❌ Sync error: \(error.localizedDescription)")
        }
        #else
        syncStatus = .error("Firebase SDK не установлен. Добавьте через Swift Package Manager.")
        print("⚠️ Firebase SDK not found. Please:")
        print("   1. File > Add Package Dependencies...")
        print("   2. URL: https://github.com/firebase/firebase-ios-sdk")
        print("   3. Select: FirebaseCore, FirebaseFirestore, FirebaseAuth")
        print("   4. Clean Build Folder (⇧⌘K) and rebuild")
        #endif
    }
    
    /// Автоматическая синхронизация при изменении данных
    func autoSync(context: ModelContext) {
        Task {
            await syncAll(context: context)
        }
    }
}

enum FirebaseError: LocalizedError {
    case notInitialized
    case syncFailed(String)
    case recordNotFound
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Firebase не инициализирован. Проверьте настройки Firebase."
        case .syncFailed(let message):
            return "Ошибка синхронизации: \(message)"
        case .recordNotFound:
            return "Запись не найдена"
        }
    }
}

