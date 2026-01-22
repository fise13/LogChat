//
//  CodeService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

class CodeService {
    static let shared = CodeService()
    
    // Детекция языка программирования
    func detectLanguage(from code: String) -> String? {
        let patterns: [String: [String]] = [
            "swift": ["import Swift", "func ", "var ", "let ", "@State", "@Published"],
            "python": ["def ", "import ", "print(", "if __name__", "class "],
            "javascript": ["function ", "const ", "let ", "var ", "=>", "console.log"],
            "typescript": ["interface ", "type ", "export ", "import ", ": string"],
            "java": ["public class", "public static void", "System.out.println", "import java"],
            "cpp": ["#include", "using namespace", "std::", "int main()"],
            "c": ["#include", "int main()", "printf(", "scanf("],
            "html": ["<!DOCTYPE", "<html", "<div", "<script"],
            "css": ["@media", "@keyframes", ".", "#", "{"],
            "sql": ["SELECT", "FROM", "WHERE", "INSERT INTO", "CREATE TABLE"],
            "bash": ["#!/bin/bash", "echo ", "if [", "for "],
            "json": ["{", "}", "\"", ":"]
        ]
        
        let codeLower = code.lowercased()
        var scores: [String: Int] = [:]
        
        for (language, keywords) in patterns {
            for keyword in keywords {
                if codeLower.contains(keyword.lowercased()) {
                    scores[language, default: 0] += 1
                }
            }
        }
        
        return scores.max(by: { $0.value < $1.value })?.key
    }
    
    // Форматирование кода (базовая версия)
    func formatCode(_ code: String, language: String?) -> String {
        // В реальном приложении здесь была бы интеграция с форматтером
        // Для Swift можно использовать swift-format
        return code
    }
}

