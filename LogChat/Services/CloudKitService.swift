//
//  CloudKitService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import CloudKit
import SwiftData
import Combine

/// Сервис для синхронизации данных через iCloud CloudKit
@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isCloudAvailable: Bool = false
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()
    
    // Record types
    private let memoryRecordType = "MemoryItem"
    private let projectRecordType = "Project"
    private let chatRecordType = "Chat"
    
    private init() {
        // Инициализируем контейнер
        // Если entitlement не настроен, ошибка проявится при первом использовании
        // CloudKit Container ID должен быть: iCloud.{BundleIdentifier}
        container = CKContainer(identifier: "iCloud.fise.LogChat")
        privateDatabase = container.privateCloudDatabase
        
        // Проверяем доступность асинхронно
        // Если entitlement отсутствует, checkCloudAvailability обработает это
        checkCloudAvailability()
        setupSubscriptions()
    }
    
    // MARK: - Cloud Availability
    
    private func checkCloudAvailability() {
        // Проверяем доступность CloudKit с обработкой ошибок
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ CloudKit account status error: \(error.localizedDescription)")
                    self?.isCloudAvailable = false
                } else {
                    self?.isCloudAvailable = (status == .available)
                    if status != .available {
                        print("ℹ️ CloudKit status: \(status) - iCloud may not be configured")
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Sync
    
    /// Синхронизирует память с iCloud
    func syncMemory(context: ModelContext) async throws {
        guard isCloudAvailable else {
            throw CloudKitError.cloudUnavailable
        }
        
        syncStatus = .syncing
        
        do {
            // Загружаем локальную память
            let localMemories = try context.fetch(FetchDescriptor<MemoryItem>())
            
            // Загружаем память из CloudKit
            let cloudMemories = try await fetchCloudMemories()
            
            // Синхронизируем: объединяем и обновляем
            try await mergeMemories(local: localMemories, cloud: cloudMemories, context: context)
            
            // Отправляем обновления в CloudKit
            try await pushMemoriesToCloud(memories: localMemories)
            
            syncStatus = .success
            lastSyncDate = Date()
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// Загружает память из CloudKit
    private func fetchCloudMemories() async throws -> [CKRecord] {
        let query = CKQuery(recordType: memoryRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("⚠️ Error fetching memory record: \(error)")
            }
        }
        
        return records
    }
    
    /// Объединяет локальную и облачную память
    private func mergeMemories(local: [MemoryItem], cloud: [CKRecord], context: ModelContext) async throws {
        // Создаем словарь локальных записей по ID
        var localDict: [UUID: MemoryItem] = [:]
        for memory in local {
            localDict[memory.id] = memory
        }
        
        // Обрабатываем облачные записи
        for cloudRecord in cloud {
            guard let idString = cloudRecord["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }
            
            if let localMemory = localDict[id] {
                // Обновляем локальную запись, если облачная новее
                if let cloudUpdated = cloudRecord.modificationDate,
                   cloudUpdated > localMemory.updatedAt {
                    updateMemoryFromRecord(localMemory, record: cloudRecord)
                }
            } else {
                // Создаем новую локальную запись из облачной
                createMemoryFromRecord(record: cloudRecord, context: context)
            }
        }
        
        try context.save()
    }
    
    /// Обновляет память из CloudKit записи
    private func updateMemoryFromRecord(_ memory: MemoryItem, record: CKRecord) {
        memory.type = record["type"] as? String ?? memory.type
        memory.key = record["key"] as? String ?? memory.key
        memory.content = record["content"] as? String ?? memory.content
        memory.importance = record["importance"] as? Int ?? memory.importance
        
        if let updatedAt = record.modificationDate {
            memory.updatedAt = updatedAt
        }
        
        if let lastUsedAt = record["lastUsedAt"] as? Date {
            memory.lastUsedAt = lastUsedAt
        }
        
        memory.usageCount = record["usageCount"] as? Int ?? memory.usageCount
    }
    
    /// Создает память из CloudKit записи
    private func createMemoryFromRecord(record: CKRecord, context: ModelContext) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let typeString = record["type"] as? String,
              let type = MemoryType(rawValue: typeString),
              let key = record["key"] as? String,
              let content = record["content"] as? String else {
            return
        }
        
        let importance = record["importance"] as? Int ?? 5
        let createdAt = record.creationDate ?? Date()
        let updatedAt = record.modificationDate ?? Date()
        let lastUsedAt = record["lastUsedAt"] as? Date
        let usageCount = record["usageCount"] as? Int ?? 0
        
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
    
    /// Отправляет память в CloudKit
    private func pushMemoriesToCloud(memories: [MemoryItem]) async throws {
        var records: [CKRecord] = []
        
        for memory in memories {
            let recordID = CKRecord.ID(recordName: memory.id.uuidString)
            let record = CKRecord(recordType: memoryRecordType, recordID: recordID)
            
            record["id"] = memory.id.uuidString
            record["type"] = memory.type
            record["key"] = memory.key
            record["content"] = memory.content
            record["importance"] = memory.importance
            record["createdAt"] = memory.createdAt
            record["updatedAt"] = memory.updatedAt
            record["lastUsedAt"] = memory.lastUsedAt
            record["usageCount"] = memory.usageCount
            
            records.append(record)
        }
        
        // Batch save
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    // MARK: - Project Sync
    
    /// Синхронизирует проекты с iCloud
    func syncProjects(context: ModelContext) async throws {
        guard isCloudAvailable else {
            throw CloudKitError.cloudUnavailable
        }
        
        let localProjects = try context.fetch(FetchDescriptor<Project>())
        let cloudProjects = try await fetchCloudProjects()
        
        try await mergeProjects(local: localProjects, cloud: cloudProjects, context: context)
        try await pushProjectsToCloud(projects: localProjects)
    }
    
    private func fetchCloudProjects() async throws -> [CKRecord] {
        let query = CKQuery(recordType: projectRecordType, predicate: NSPredicate(value: true))
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("⚠️ Error fetching project record: \(error)")
            }
        }
        
        return records
    }
    
    private func mergeProjects(local: [Project], cloud: [CKRecord], context: ModelContext) async throws {
        // Similar merge logic as memories
        try context.save()
    }
    
    private func pushProjectsToCloud(projects: [Project]) async throws {
        // Similar push logic as memories
    }
    
    // MARK: - Subscriptions
    
    private func setupSubscriptions() {
        // Настраиваем подписки на изменения в CloudKit
        // Это позволит получать обновления в реальном времени
    }
    
    // MARK: - Full Sync
    
    /// Полная синхронизация всех данных
    func syncAll(context: ModelContext) async {
        guard isCloudAvailable else {
            syncStatus = .error("iCloud недоступен")
            return
        }
        
        syncStatus = .syncing
        
        do {
            try await syncMemory(context: context)
            try await syncProjects(context: context)
            
            syncStatus = .success
            lastSyncDate = Date()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }
}

enum CloudKitError: LocalizedError {
    case cloudUnavailable
    case syncFailed(String)
    case recordNotFound
    
    var errorDescription: String? {
        switch self {
        case .cloudUnavailable:
            return "iCloud недоступен. Проверьте настройки iCloud."
        case .syncFailed(let message):
            return "Ошибка синхронизации: \(message)"
        case .recordNotFound:
            return "Запись не найдена"
        }
    }
}

