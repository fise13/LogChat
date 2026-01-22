//
//  WorkspaceService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@MainActor
class WorkspaceService {
    static let shared = WorkspaceService()
    
    private init() {}
    
    /// Get or create default workspace
    func getDefaultWorkspace(context: ModelContext) -> Workspace {
        let descriptor = FetchDescriptor<Workspace>(
            predicate: #Predicate<Workspace> { $0.isDefault == true }
        )
        
        do {
            if let existing = try context.fetch(descriptor).first {
                return existing
            }
        } catch {
            print("❌ Error fetching default workspace: \(error)")
        }
        
        // Create default workspace
        let defaultWorkspace = Workspace(
            name: "Personal",
            icon: "person.fill",
            color: "blue",
            isDefault: true
        )
        context.insert(defaultWorkspace)
        
        do {
            try context.save()
        } catch {
            print("❌ Error creating default workspace: \(error)")
        }
        
        return defaultWorkspace
    }
    
    /// Get all workspaces
    func getAllWorkspaces(context: ModelContext) -> [Workspace] {
        let descriptor = FetchDescriptor<Workspace>()
        
        do {
            var workspaces = try context.fetch(descriptor)
            // Sort manually since SwiftData has limitations with Bool sorting
            workspaces.sort { workspace1, workspace2 in
                if workspace1.isDefault != workspace2.isDefault {
                    return workspace1.isDefault // Default workspaces first
                }
                return workspace1.name < workspace2.name
            }
            return workspaces
        } catch {
            print("❌ Error fetching workspaces: \(error)")
            return []
        }
    }
    
    /// Get workspace by ID
    func getWorkspace(id: UUID, context: ModelContext) -> Workspace? {
        let descriptor = FetchDescriptor<Workspace>()
        
        do {
            let workspaces = try context.fetch(descriptor)
            return workspaces.first { $0.id == id }
        } catch {
            print("❌ Error fetching workspace: \(error)")
            return nil
        }
    }
    
    /// Create new workspace
    func createWorkspace(
        name: String,
        icon: String = "folder.fill",
        color: String = "blue",
        context: ModelContext
    ) -> Workspace {
        let workspace = Workspace(
            name: name,
            icon: icon,
            color: color
        )
        context.insert(workspace)
        
        do {
            try context.save()
        } catch {
            print("❌ Error creating workspace: \(error)")
        }
        
        return workspace
    }
    
    /// Delete workspace (moves memories to default workspace)
    func deleteWorkspace(_ workspace: Workspace, context: ModelContext) {
        guard !workspace.isDefault else {
            print("⚠️ Cannot delete default workspace")
            return
        }
        
        // Move all memories to default workspace
        let defaultWorkspace = getDefaultWorkspace(context: context)
        
        let descriptor = FetchDescriptor<MemoryItem>()
        
        do {
            let allMemories = try context.fetch(descriptor)
            let memories = allMemories.filter { $0.workspaceId == workspace.id }
            for memory in memories {
                memory.workspaceId = defaultWorkspace.id
            }
            
            context.delete(workspace)
            try context.save()
        } catch {
            print("❌ Error deleting workspace: \(error)")
        }
    }
    
    /// Get current workspace (from UserDefaults)
    func getCurrentWorkspaceId() -> UUID? {
        if let idString = UserDefaults.standard.string(forKey: "currentWorkspaceId"),
           let id = UUID(uuidString: idString) {
            return id
        }
        return nil
    }
    
    /// Set current workspace
    func setCurrentWorkspaceId(_ id: UUID?) {
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: "currentWorkspaceId")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentWorkspaceId")
        }
    }
}
