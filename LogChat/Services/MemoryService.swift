//
//  MemoryService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@MainActor
class MemoryService {
    static let shared = MemoryService()
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    func saveMemory(
        context: ModelContext,
        type: MemoryType,
        key: String,
        content: String,
        importance: Int = 5,
        workspaceId: UUID? = nil,
        tier: MemoryTier? = nil
    ) {
        // Get current workspace if not specified
        let finalWorkspaceId = workspaceId ?? WorkspaceService.shared.getCurrentWorkspaceId()
        
        // Проверяем, есть ли уже память с таким ключом в том же workspace
        let descriptor = FetchDescriptor<MemoryItem>(
            predicate: #Predicate<MemoryItem> { 
                $0.key == key && 
                $0.type == type.rawValue &&
                $0.workspaceId == finalWorkspaceId
            }
        )
        
        do {
            let existing = try context.fetch(descriptor).first
            
            if let existing = existing {
                // Обновляем существующую память
                existing.content = content
                existing.updatedAt = Date()
                
                // Используем максимум из текущей и новой важности (память может стать важнее)
                let importanceService = MemoryImportanceService.shared
                let recalculatedImportance = importanceService.recalculateImportance(
                    currentImportance: existing.importance,
                    usageCount: existing.usageCount,
                    daysSinceLastUse: existing.lastUsedAt.map {
                        Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
                    } ?? 0,
                    daysSinceCreation: Calendar.current.dateComponents([.day], from: existing.createdAt, to: Date()).day ?? 0,
                    tier: existing.memoryTier
                )
                
                existing.importance = max(importance, recalculatedImportance)
                print("💾 Updated memory: \(key) (importance: \(existing.importance))")
            } else {
                // Определяем tier если не указан
                let finalTier = tier ?? (importance >= 7 ? .longTerm : importance >= 5 ? .midTerm : .shortTerm)
                
                // Создаем новую память с рассчитанной важностью
                let memory = MemoryItem(
                    type: type,
                    key: key,
                    content: content,
                    importance: importance,
                    tier: finalTier,
                    workspaceId: finalWorkspaceId
                )
                context.insert(memory)
                print("💾 Created new memory: \(key) (importance: \(importance), tier: \(finalTier.rawValue))")
            }
            
            try context.save()
            
            // Синхронизируем с Firebase
            if FirebaseService.shared.isFirebaseAvailable {
                Task {
                    try? await FirebaseService.shared.syncMemory(context: context)
                }
            }
        } catch {
            print("❌ Error saving memory: \(error)")
        }
    }
    
    func getMemories(
        context: ModelContext,
        type: MemoryType? = nil,
        workspaceId: UUID? = nil,
        tier: MemoryTier? = nil,
        limit: Int? = nil
    ) -> [MemoryItem] {
        // Get current workspace if not specified
        let finalWorkspaceId = workspaceId ?? WorkspaceService.shared.getCurrentWorkspaceId()
        
        let descriptor: FetchDescriptor<MemoryItem>
        
        // Build predicate
        var predicates: [String] = []
        if let type = type {
            predicates.append("$0.type == '\(type.rawValue)'")
        }
        if let workspaceId = finalWorkspaceId {
            predicates.append("$0.workspaceId == workspaceId")
        }
        if let tier = tier {
            predicates.append("$0.tier == '\(tier.rawValue)'")
        }
        
        if !predicates.isEmpty {
            // Use simple predicate for now (SwiftData predicate builder limitations)
            if let type = type {
                descriptor = FetchDescriptor<MemoryItem>(
                    predicate: #Predicate<MemoryItem> { $0.type == type.rawValue },
                    sortBy: [
                        SortDescriptor(\.importance, order: .reverse),
                        SortDescriptor(\.updatedAt, order: .reverse)
                    ]
                )
            } else {
                descriptor = FetchDescriptor<MemoryItem>(
                    sortBy: [
                        SortDescriptor(\.importance, order: .reverse),
                        SortDescriptor(\.updatedAt, order: .reverse)
                    ]
                )
            }
        } else {
            descriptor = FetchDescriptor<MemoryItem>(
                sortBy: [
                    SortDescriptor(\.importance, order: .reverse),
                    SortDescriptor(\.updatedAt, order: .reverse)
                ]
            )
        }
        
        do {
            var memories = try context.fetch(descriptor)
            
            // Filter by workspace and tier in memory (SwiftData predicate limitations)
            if let workspaceId = finalWorkspaceId {
                memories = memories.filter { $0.workspaceId == workspaceId }
            }
            if let tier = tier {
                memories = memories.filter { $0.memoryTier == tier }
            }
            
            if let limit = limit {
                memories = Array(memories.prefix(limit))
            }
            return memories
        } catch {
            print("❌ Error fetching memories: \(error)")
            return []
        }
    }
    
    func getMemory(context: ModelContext, key: String, type: MemoryType) -> MemoryItem? {
        let descriptor = FetchDescriptor<MemoryItem>(
            predicate: #Predicate<MemoryItem> { $0.key == key && $0.type == type.rawValue }
        )
        
        do {
            return try context.fetch(descriptor).first
        } catch {
            print("❌ Error fetching memory: \(error)")
            return nil
        }
    }
    
    func deleteMemory(context: ModelContext, memory: MemoryItem) {
        context.delete(memory)
        do {
            try context.save()
        } catch {
            print("❌ Error deleting memory: \(error)")
        }
    }
    
    func updateMemoryUsage(context: ModelContext, memory: MemoryItem) {
        memory.lastUsedAt = Date()
        memory.usageCount += 1
        
        // Recalculate importance based on usage
        let importanceService = MemoryImportanceService.shared
        let daysSinceLastUse = 0 // Just used
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: memory.createdAt, to: Date()).day ?? 0
        
        let newImportance = importanceService.recalculateImportance(
            currentImportance: memory.importance,
            usageCount: memory.usageCount,
            daysSinceLastUse: daysSinceLastUse,
            daysSinceCreation: daysSinceCreation,
            tier: memory.memoryTier
        )
        
        memory.importance = newImportance
        memory.updatedAt = Date()
        
        do {
            try context.save()
        } catch {
            print("❌ Error updating memory usage: \(error)")
        }
    }
    
    /// Periodic cleanup: forget low-importance memories and recalculate importance
    func performMemoryMaintenance(context: ModelContext) {
        let importanceService = MemoryImportanceService.shared
        let descriptor = FetchDescriptor<MemoryItem>()
        
        do {
            let allMemories = try context.fetch(descriptor)
            let calendar = Calendar.current
            let now = Date()
            
            var forgottenCount = 0
            var updatedCount = 0
            var tierUpgradedCount = 0
            var tierDowngradedCount = 0
            
            for memory in allMemories {
                let daysSinceLastUse = memory.lastUsedAt.map {
                    calendar.dateComponents([.day], from: $0, to: now).day ?? 0
                } ?? calendar.dateComponents([.day], from: memory.createdAt, to: now).day ?? 0
                
                let daysSinceCreation = calendar.dateComponents([.day], from: memory.createdAt, to: now).day ?? 0
                
                // Check if should forget (tier-aware)
                if importanceService.shouldForget(
                    importance: memory.importance,
                    usageCount: memory.usageCount,
                    daysSinceLastUse: daysSinceLastUse,
                    daysSinceCreation: daysSinceCreation,
                    tier: memory.memoryTier
                ) {
                    context.delete(memory)
                    forgottenCount += 1
                    continue
                }
                
                // Recalculate importance
                let oldImportance = memory.importance
                let newImportance = importanceService.recalculateImportance(
                    currentImportance: memory.importance,
                    usageCount: memory.usageCount,
                    daysSinceLastUse: daysSinceLastUse,
                    daysSinceCreation: daysSinceCreation,
                    tier: memory.memoryTier
                )
                
                // Update importance if changed
                if newImportance != oldImportance {
                    memory.importance = newImportance
                    memory.updatedAt = now
                    updatedCount += 1
                }
                
                // Auto-adjust tier based on importance and usage
                let oldTier = memory.memoryTier
                let newTier: MemoryTier
                
                if newImportance >= 7 && daysSinceLastUse <= 30 && memory.usageCount >= 5 {
                    newTier = .longTerm
                } else if newImportance >= 5 && daysSinceLastUse <= 60 {
                    newTier = .midTerm
                } else if newImportance < 5 || daysSinceLastUse > 60 {
                    newTier = .shortTerm
                } else {
                    newTier = oldTier
                }
                
                if newTier != oldTier {
                    memory.memoryTier = newTier
                    if newTier.importanceThreshold > oldTier.importanceThreshold {
                        tierUpgradedCount += 1
                    } else {
                        tierDowngradedCount += 1
                    }
                }
            }
            
            try context.save()
            
            if forgottenCount > 0 || updatedCount > 0 || tierUpgradedCount > 0 || tierDowngradedCount > 0 {
                print("🧹 Memory maintenance: forgotten \(forgottenCount), updated \(updatedCount), upgraded \(tierUpgradedCount), downgraded \(tierDowngradedCount)")
            }
        } catch {
            print("❌ Error performing memory maintenance: \(error)")
        }
    }
    
    // MARK: - Context Building
    
    func buildMemoryContext(
        context: ModelContext,
        relevantKeys: [String]? = nil,
        workspaceId: UUID? = nil
    ) -> String {
        let importanceService = MemoryImportanceService.shared
        let minImportance = importanceService.getMinimumImportanceThreshold()
        
        // Get memories for current workspace
        let finalWorkspaceId = workspaceId ?? WorkspaceService.shared.getCurrentWorkspaceId()
        var memories = getMemories(context: context, workspaceId: finalWorkspaceId)
            .filter { $0.importance >= minImportance }
        
        // Если указаны ключи, фильтруем
        let relevantMemories = if let keys = relevantKeys {
            memories.filter { keys.contains($0.key) }
        } else {
            memories
        }
        
        // Сортируем по важности и последнему использованию
        let sorted = relevantMemories.sorted { mem1, mem2 in
            if mem1.importance != mem2.importance {
                return mem1.importance > mem2.importance
            }
            let date1 = mem1.lastUsedAt ?? mem1.updatedAt
            let date2 = mem2.lastUsedAt ?? mem2.updatedAt
            return date1 > date2
        }
        
        // Берем топ-10 самых важных
        let topMemories = Array(sorted.prefix(10))
        
        if topMemories.isEmpty {
            return ""
        }
        
        var contextString = "\n\n--- USER MEMORY CONTEXT ---\n"
        contextString += "The following information is known about the user:\n\n"
        
        for memory in topMemories {
            // Include importance score and tier in context for AI awareness
            contextString += "[\(memory.memoryType.displayName.uppercased())] \(memory.key) (importance: \(memory.importance)/10, tier: \(memory.memoryTier.rawValue)): \(memory.content)\n"
        }
        
        contextString += "\nUse this context to provide personalized and relevant responses.\n"
        contextString += "--- END MEMORY CONTEXT ---\n"
        
        return contextString
    }
    
    // MARK: - Export/Import
    
    /// Export memories to JSON
    func exportMemories(
        context: ModelContext,
        workspaceId: UUID? = nil,
        includeDeleted: Bool = false
    ) -> Data? {
        let finalWorkspaceId = workspaceId ?? WorkspaceService.shared.getCurrentWorkspaceId()
        let memories = getMemories(context: context, workspaceId: finalWorkspaceId)
        
        let exportData: [[String: Any]] = memories.map { memory in
            [
                "id": memory.id.uuidString,
                "type": memory.type,
                "key": memory.key,
                "content": memory.content,
                "importance": memory.importance,
                "tier": memory.tier ?? "",
                "workspaceId": memory.workspaceId?.uuidString ?? "",
                "createdAt": ISO8601DateFormatter().string(from: memory.createdAt),
                "updatedAt": ISO8601DateFormatter().string(from: memory.updatedAt),
                "lastUsedAt": memory.lastUsedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "usageCount": memory.usageCount
            ]
        }
        
        do {
            return try JSONSerialization.data(withJSONObject: [
                "version": "1.0",
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "memories": exportData
            ], options: .prettyPrinted)
        } catch {
            print("❌ Error exporting memories: \(error)")
            return nil
        }
    }
    
    /// Import memories from JSON
    func importMemories(
        data: Data,
        context: ModelContext,
        workspaceId: UUID? = nil,
        mergeStrategy: ImportMergeStrategy = .updateExisting
    ) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let memoriesData = json["memories"] as? [[String: Any]] else {
            throw NSError(domain: "MemoryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid import format"])
        }
        
        let finalWorkspaceId = workspaceId ?? WorkspaceService.shared.getCurrentWorkspaceId()
        let dateFormatter = ISO8601DateFormatter()
        
        for memoryData in memoriesData {
            guard let idString = memoryData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let typeString = memoryData["type"] as? String,
                  let type = MemoryType(rawValue: typeString),
                  let key = memoryData["key"] as? String,
                  let content = memoryData["content"] as? String else {
                continue
            }
            
            let importance = memoryData["importance"] as? Int ?? 5
            let tierString = memoryData["tier"] as? String
            let tier = tierString.flatMap { MemoryTier(rawValue: $0) }
            let createdAt = (memoryData["createdAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
            let updatedAt = (memoryData["updatedAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
            let lastUsedAt = (memoryData["lastUsedAt"] as? String).flatMap { dateFormatter.date(from: $0) }
            let usageCount = memoryData["usageCount"] as? Int ?? 0
            
            // Check if memory exists
            let existing = getMemory(context: context, key: key, type: type)
            
            switch mergeStrategy {
            case .skipExisting:
                if existing != nil {
                    continue
                }
            case .updateExisting:
                if let existing = existing {
                    existing.content = content
                    existing.importance = max(existing.importance, importance)
                    existing.updatedAt = updatedAt
                    existing.lastUsedAt = lastUsedAt
                    existing.usageCount = max(existing.usageCount, usageCount)
                    if let tier = tier {
                        existing.memoryTier = tier
                    }
                    continue
                }
            case .replaceAll:
                if let existing = existing {
                    context.delete(existing)
                }
            }
            
            // Create new memory
            let memory = MemoryItem(
                id: id,
                type: type,
                key: key,
                content: content,
                importance: importance,
                tier: tier,
                workspaceId: finalWorkspaceId ?? existing?.workspaceId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastUsedAt: lastUsedAt,
                usageCount: usageCount
            )
            context.insert(memory)
        }
        
        try context.save()
        print("✅ Imported \(memoriesData.count) memories")
    }
    
    enum ImportMergeStrategy {
        case skipExisting
        case updateExisting
        case replaceAll
    }
}

