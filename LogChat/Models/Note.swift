//
//  Note.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var colorRawValue: String // Храним как String для SwiftData, но используем computed property
    
    // Type-safe accessor
    var color: NoteColor {
        get {
            NoteColor(rawValue: colorRawValue) ?? .default
        }
        set {
            colorRawValue = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        color: NoteColor = .default
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.colorRawValue = color.rawValue
    }
}

@Model
final class FocusSession {
    var id: UUID
    var duration: TimeInterval // Длительность сессии в секундах
    var startTime: Date
    var endTime: Date?
    var isCompleted: Bool
    var chatId: UUID? // Связанный чат
    var modeRawValue: String // Храним как String для SwiftData, но используем computed property
    var notes: String? // Заметки о сессии
    
    // Type-safe accessor
    var mode: AIMode {
        get {
            AIMode(rawValue: modeRawValue) ?? .coding
        }
        set {
            modeRawValue = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        duration: TimeInterval = 1500, // 25 минут по умолчанию
        startTime: Date = Date(),
        endTime: Date? = nil,
        isCompleted: Bool = false,
        chatId: UUID? = nil,
        mode: AIMode = .coding,
        notes: String? = nil
    ) {
        self.id = id
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.isCompleted = isCompleted
        self.chatId = chatId
        self.modeRawValue = mode.rawValue
        self.notes = notes
    }
}

