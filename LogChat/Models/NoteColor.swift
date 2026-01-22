//
//  NoteColor.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftUI

enum NoteColor: String, CaseIterable, Codable {
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    static var `default`: NoteColor {
        return .blue
    }
}

