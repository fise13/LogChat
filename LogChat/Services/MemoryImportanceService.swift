//
//  MemoryImportanceService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Service for calculating and managing memory importance scores
@MainActor
class MemoryImportanceService {
    static let shared = MemoryImportanceService()
    
    private init() {}
    
    /// Calculate initial importance score based on content and context
    func calculateImportance(
        content: String,
        type: MemoryType,
        context: String? = nil
    ) -> Int {
        var score = 5 // Base score
        
        // Type-based importance
        switch type {
        case .profile:
            score += 3 // Profile info is always important
        case .preference:
            score += 2
        case .project:
            score += 2
        case .fact:
            score += 0 // Facts start neutral
        }
        
        // Content length - longer content might be more detailed/important
        if content.count > 100 {
            score += 1
        } else if content.count < 20 {
            score -= 1 // Very short content might be noise
        }
        
        // Keywords that indicate importance
        let importantKeywords = [
            "важно", "important", "critical", "ключевой",
            "always", "всегда", "never", "никогда",
            "любимый", "favorite", "люблю", "love",
            "ненавижу", "hate", "не люблю", "don't like"
        ]
        
        let contentLower = content.lowercased()
        for keyword in importantKeywords {
            if contentLower.contains(keyword) {
                score += 2
                break
            }
        }
        
        // Noise indicators - reduce score
        let noisePatterns = [
            "ok", "ок", "да", "yes", "no", "нет",
            "спасибо", "thanks", "thank you",
            "хм", "hmm", "ага", "yeah"
        ]
        
        for pattern in noisePatterns {
            if contentLower.trimmingCharacters(in: .whitespacesAndNewlines) == pattern {
                score -= 3
                break
            }
        }
        
        // Clamp to valid range
        return max(1, min(10, score))
    }
    
    /// Recalculate importance based on usage patterns and tier
    func recalculateImportance(
        currentImportance: Int,
        usageCount: Int,
        daysSinceLastUse: Int,
        daysSinceCreation: Int,
        tier: MemoryTier? = nil
    ) -> Int {
        var newImportance = Double(currentImportance)
        let memoryTier = tier ?? (currentImportance >= 7 ? .longTerm : currentImportance >= 5 ? .midTerm : .shortTerm)
        let tierTTL = memoryTier.ttlDays
        
        // Increase importance based on usage
        // Frequent use = important
        if usageCount > 10 {
            newImportance += 1.5
        } else if usageCount > 5 {
            newImportance += 0.5
        } else if usageCount == 0 && daysSinceCreation > tierTTL / 2 {
            // Never used and old = less important
            newImportance -= 1.0
        }
        
        // Decrease importance if not used recently (tier-based decay)
        if daysSinceLastUse > tierTTL {
            newImportance -= 2.0 // Exceeded TTL
        } else if daysSinceLastUse > Int(Double(tierTTL) * 0.75) {
            newImportance -= 1.0
        } else if daysSinceLastUse > tierTTL / 2 {
            newImportance -= 0.5
        } else if daysSinceLastUse <= 7 {
            newImportance += 0.5 // Recently used = boost
        }
        
        // Very old memories that are never used decay faster
        if daysSinceCreation > tierTTL * 2 && usageCount < 3 {
            newImportance -= 1.5
        }
        
        // Tier-specific adjustments
        switch memoryTier {
        case .longTerm:
            // Long-term memories decay slower
            if daysSinceLastUse > tierTTL {
                newImportance -= 1.0 // Less aggressive decay
            }
        case .midTerm:
            // Normal decay
            break
        case .shortTerm:
            // Short-term memories decay faster
            if daysSinceLastUse > tierTTL / 2 {
                newImportance -= 0.5 // Additional decay
            }
        }
        
        // Clamp to valid range
        let rounded = Int(newImportance.rounded())
        let clamped = max(1, min(10, rounded))
        return clamped
    }
    
    /// Determine if memory should be forgotten (tier-aware)
    func shouldForget(
        importance: Int,
        usageCount: Int,
        daysSinceLastUse: Int,
        daysSinceCreation: Int,
        tier: MemoryTier? = nil
    ) -> Bool {
        let memoryTier = tier ?? (importance >= 7 ? .longTerm : importance >= 5 ? .midTerm : .shortTerm)
        let tierTTL = memoryTier.ttlDays
        
        // Never forget long-term memories with high importance
        if memoryTier == .longTerm && importance >= 7 {
            return false
        }
        
        // Forget if exceeded tier TTL and low importance
        if daysSinceLastUse > Int(Double(tierTTL) * 1.5) && importance <= 3 && usageCount < 2 {
            return true
        }
        
        // Forget low importance memories that are old and unused (tier-specific thresholds)
        if importance <= 3 {
            let threshold = memoryTier == .shortTerm ? 30 : memoryTier == .midTerm ? 60 : 90
            if daysSinceLastUse > threshold && usageCount < 2 {
                return true
            }
        }
        
        // Forget very old, unused memories (tier-aware)
        if daysSinceCreation > tierTTL * 2 && usageCount == 0 {
            return true
        }
        
        return false
    }
    
    /// Calculate decay rate for memory (how fast it loses importance)
    func calculateDecayRate(importance: Int, type: MemoryType) -> Double {
        // Higher importance = slower decay
        let baseDecay = 0.1 // Per month
        
        switch type {
        case .profile:
            return baseDecay * 0.3 // Profile info decays very slowly
        case .preference:
            return baseDecay * 0.5
        case .project:
            return baseDecay * 0.7
        case .fact:
            return baseDecay * 1.0 // Facts decay normally
        }
    }
    
    /// Get importance threshold for filtering memories
    func getMinimumImportanceThreshold() -> Int {
        // User can configure this, default is 3
        return UserDefaults.standard.integer(forKey: "memoryMinImportanceThreshold")
            .clamped(to: 1...5) ?? 3
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int? {
        if self < range.lowerBound || self > range.upperBound {
            return nil
        }
        return self
    }
}
