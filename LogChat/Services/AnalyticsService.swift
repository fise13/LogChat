//
//  AnalyticsService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// On-device analytics service for tracking events
@MainActor
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private var events: [AnalyticsEvent] = []
    private let maxEvents = 1000 // Keep last 1000 events
    private let isEnabled: Bool
    
    private init() {
        // Only enable in debug builds or if user opted in
        #if DEBUG
        isEnabled = true
        #else
        isEnabled = UserDefaults.standard.bool(forKey: "analyticsEnabled")
        #endif
    }
    
    /// Track an event
    func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        events.append(event)
        
        // Keep only last N events
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        
        print("📊 Analytics: \(event.name) - \(event.properties)")
    }
    
    /// Track simple event
    func track(name: String, properties: [String: Any] = [:]) {
        track(AnalyticsEvent(name: name, properties: properties, timestamp: Date()))
    }
    
    /// Get recent events
    func getRecentEvents(limit: Int = 100) -> [AnalyticsEvent] {
        return Array(events.suffix(limit))
    }
    
    /// Get events for a specific time period
    func getEvents(since date: Date) -> [AnalyticsEvent] {
        return events.filter { $0.timestamp >= date }
    }
    
    /// Clear all events
    func clearEvents() {
        events.removeAll()
    }
    
    /// Get statistics
    func getStatistics(since date: Date? = nil) -> AnalyticsStatistics {
        let relevantEvents = date.map { getEvents(since: $0) } ?? events
        
        var eventCounts: [String: Int] = [:]
        var errorCount = 0
        var totalMessages = 0
        var totalResponseTime: TimeInterval = 0
        var responseCount = 0
        var providerUsage: [String: Int] = [:]
        
        for event in relevantEvents {
            eventCounts[event.name, default: 0] += 1
            
            if event.name == "message_sent" {
                totalMessages += 1
            }
            
            if event.name == "llm_error" {
                errorCount += 1
            }
            
            if event.name == "llm_response_complete", let duration = event.properties["duration"] as? TimeInterval {
                totalResponseTime += duration
                responseCount += 1
            }
            
            if let provider = event.properties["provider"] as? String {
                providerUsage[provider, default: 0] += 1
            }
        }
        
        let avgResponseTime = responseCount > 0 ? totalResponseTime / Double(responseCount) : 0
        let errorRate = totalMessages > 0 ? Double(errorCount) / Double(totalMessages) : 0
        
        return AnalyticsStatistics(
            totalEvents: relevantEvents.count,
            eventCounts: eventCounts,
            totalMessages: totalMessages,
            errorCount: errorCount,
            errorRate: errorRate,
            averageResponseTime: avgResponseTime,
            providerUsage: providerUsage
        )
    }
}

struct AnalyticsEvent {
    let name: String
    let properties: [String: Any]
    let timestamp: Date
}

struct AnalyticsStatistics {
    let totalEvents: Int
    let eventCounts: [String: Int]
    let totalMessages: Int
    let errorCount: Int
    let errorRate: Double
    let averageResponseTime: TimeInterval
    let providerUsage: [String: Int]
}
