//
//  Project.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@Model
final class Project: Identifiable {
    var id: UUID
    var name: String
    var projectDescription: String?
    var status: String // "active", "paused", "completed"
    var priority: Int // 1-10
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var progress: Double // 0.0 - 1.0
    var notes: String?
    var lastAnalyzedAt: Date?
    
    @Relationship(deleteRule: .cascade) var tasks: [ProjectTask]?
    @Relationship(deleteRule: .cascade) var reports: [ProjectReport]?
    
    init(
        id: UUID = UUID(),
        name: String,
        projectDescription: String? = nil,
        status: String = "active",
        priority: Int = 5,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        progress: Double = 0.0,
        notes: String? = nil,
        lastAnalyzedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.progress = progress
        self.notes = notes
        self.lastAnalyzedAt = lastAnalyzedAt
        self.tasks = []
        self.reports = []
    }
}

@Model
final class ProjectTask: Identifiable {
    var id: UUID
    var title: String
    var taskDescription: String?
    var isCompleted: Bool
    var priority: Int
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var project: Project?
    
    init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String? = nil,
        isCompleted: Bool = false,
        priority: Int = 5,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ProjectReport {
    var id: UUID
    var title: String
    var content: String
    var type: String // "analysis", "progress", "recommendations"
    var createdAt: Date
    var project: Project?
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        type: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.type = type
        self.createdAt = createdAt
    }
}

