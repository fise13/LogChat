//
//  MemorySuggestion.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Represents a memory suggestion from AI
struct MemorySuggestion: Identifiable, Hashable {
    let id = UUID()
    let type: MemoryType
    let key: String
    let content: String
    let importance: Int
    let reason: String?
    
    var displayType: String {
        type.displayName
    }
    
    var importanceStars: Int {
        (importance + 1) / 2 // Convert 1-10 to 1-5 stars
    }
}
