//
//  ResearchState.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

enum ResearchState: String, Codable {
    case analyzing = "analyzing"           // Анализирую запрос
    case clarifying = "clarifying"         // Уточняю детали
    case researching = "researching"       // Ищу информацию
    case synthesizing = "synthesizing"     // Формирую вывод
    case complete = "complete"             // Завершено
    
    var displayName: String {
        switch self {
        case .analyzing: return "Analyzing..."
        case .clarifying: return "Clarifying details..."
        case .researching: return "Researching..."
        case .synthesizing: return "Forming conclusion..."
        case .complete: return "Complete"
        }
    }
    
    var icon: String {
        switch self {
        case .analyzing: return "brain.head.profile"
        case .clarifying: return "questionmark.circle.fill"
        case .researching: return "magnifyingglass"
        case .synthesizing: return "doc.text.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .analyzing: return "blue"
        case .clarifying: return "orange"
        case .researching: return "purple"
        case .synthesizing: return "green"
        case .complete: return "gray"
        }
    }
}

