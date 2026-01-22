//
//  LanguageDetector.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

#if os(iOS)
import NaturalLanguage
#endif

struct LanguageDetector {
    /// Detect programming language in code
    static func detectCodeLanguage(_ text: String) -> String? {
        return CodeService.shared.detectLanguage(from: text)
    }
    
    /// Detect natural language (human language)
    static func detectNaturalLanguage(_ text: String) -> String {
        // Remove code blocks for better natural language detection
        let cleanedText = removeCodeBlocks(from: text)
        
        guard !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "en" // Default to English if empty
        }
        
        #if os(iOS)
        // Use iOS Natural Language framework for better detection
        if #available(iOS 12.0, *) {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(cleanedText)
            
            if let dominantLanguage = recognizer.dominantLanguage {
                return dominantLanguage.rawValue
            }
        }
        #endif
        
        // Fallback to simple pattern matching
        return detectLanguageByPattern(cleanedText)
    }
    
    /// Comprehensive language detection - tries code first, then natural language
    static func detectLanguage(_ text: String) -> (type: LanguageType, code: String?) {
        // First, check if it's code
        if let codeLang = detectCodeLanguage(text) {
            return (.code, codeLang)
        }
        
        // Then check natural language
        let naturalLang = detectNaturalLanguage(text)
        return (.natural, naturalLang)
    }
    
    /// Remove code blocks from text for better natural language detection
    private static func removeCodeBlocks(from text: String) -> String {
        var result = text
        // Remove ```code blocks```
        result = result.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        // Remove `inline code`
        result = result.replacingOccurrences(of: #"`[^`]+`"#, with: "", options: .regularExpression)
        return result
    }
    
    /// Pattern-based language detection (fallback)
    private static func detectLanguageByPattern(_ text: String) -> String {
        let patterns: [(String, String)] = [
            ("[А-Яа-яЁё]", "ru"), // Russian Cyrillic
            ("[А-Яа-я]", "bg"), // Bulgarian
            ("[Ѐ-ӿ]", "mk"), // Macedonian
            ("[а-яё]", "uk"), // Ukrainian
            ("[ა-ჰ]", "ka"), // Georgian
            ("[Ա-Ֆ]", "hy"), // Armenian
            ("[А-Яа-я]", "sr"), // Serbian Cyrillic
            ("[ა-ჰ]", "ka"), // Georgian
            ("[α-ωΑ-Ω]", "el"), // Greek
            ("[א-ת]", "he"), // Hebrew
            ("[ا-ي]", "ar"), // Arabic
            ("[ぁ-ゟ]", "ja"), // Japanese Hiragana
            ("[゠-ヿ]", "ja"), // Japanese Katakana
            ("[一-龯]", "zh"), // Chinese
            ("[가-힣]", "ko"), // Korean
            ("[ก-๙]", "th"), // Thai
            ("[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ]", "es"), // Spanish accented
            ("[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ]", "fr"), // French accented
            ("[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ]", "de"), // German umlauts
            ("[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ]", "it"), // Italian accented
            ("[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ]", "pt"), // Portuguese accented
        ]
        
        for (pattern, langCode) in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return langCode
            }
        }
        
        return "en" // Default to English
    }
    
    /// Get display name for language code
    static func languageDisplayName(_ code: String) -> String {
        let languages: [String: String] = [
            "en": "English",
            "ru": "Русский",
            "es": "Español",
            "fr": "Français",
            "de": "Deutsch",
            "it": "Italiano",
            "pt": "Português",
            "zh": "中文",
            "ja": "日本語",
            "ko": "한국어",
            "ar": "العربية",
            "he": "עברית",
            "hi": "हिन्दी",
            "th": "ไทย",
            "tr": "Türkçe",
            "pl": "Polski",
            "nl": "Nederlands",
            "sv": "Svenska",
            "da": "Dansk",
            "no": "Norsk",
            "fi": "Suomi",
            "cs": "Čeština",
            "hu": "Magyar",
            "ro": "Română",
            "bg": "Български",
            "uk": "Українська",
            "el": "Ελληνικά",
            "ka": "ქართული",
            "hy": "Հայերեն",
            "sr": "Српски",
            "mk": "Македонски",
            // Code languages
            "swift": "Swift",
            "python": "Python",
            "javascript": "JavaScript",
            "typescript": "TypeScript",
            "java": "Java",
            "cpp": "C++",
            "c": "C",
            "html": "HTML",
            "css": "CSS",
            "sql": "SQL",
            "bash": "Bash",
            "json": "JSON",
            "rust": "Rust",
            "go": "Go",
            "kotlin": "Kotlin",
            "php": "PHP",
            "ruby": "Ruby",
        ]
        
        return languages[code.lowercased()] ?? code.uppercased()
    }
    
    enum LanguageType {
        case code
        case natural
    }
}

