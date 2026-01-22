//
//  Message.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftUI

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    var imageData: Data?
    var isPinned: Bool
    var tokenCount: Int
    var language: String?
    var tokensPerSecond: Double?
    var searchResults: [SearchResult]?
    
    init(id: UUID = UUID(), content: String, role: MessageRole, timestamp: Date = Date(), imageData: Data? = nil, isPinned: Bool = false, tokenCount: Int = 0, language: String? = nil, tokensPerSecond: Double? = nil, searchResults: [SearchResult]? = nil) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.imageData = imageData
        self.isPinned = isPinned
        self.tokenCount = tokenCount
        self.language = language
        self.tokensPerSecond = tokensPerSecond
        self.searchResults = searchResults
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}
