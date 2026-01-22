//
//  DebugConsoleView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

#if DEBUG
struct DebugConsoleView: View {
    @State private var events: [AnalyticsEvent] = []
    @State private var statistics: AnalyticsStatistics?
    @State private var selectedTimeframe: Timeframe = .today
    
    enum Timeframe: String, CaseIterable {
        case today = "Today"
        case week = "Last Week"
        case month = "Last Month"
        case all = "All Time"
        
        var date: Date? {
            let calendar = Calendar.current
            switch self {
            case .today:
                return calendar.startOfDay(for: Date())
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: Date())
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: Date())
            case .all:
                return nil
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Statistics Section
                if let stats = statistics {
                    Section("Statistics") {
                        StatRow(label: "Total Events", value: "\(stats.totalEvents)")
                        StatRow(label: "Messages Sent", value: "\(stats.totalMessages)")
                        StatRow(label: "Errors", value: "\(stats.errorCount)")
                        StatRow(label: "Error Rate", value: String(format: "%.1f%%", stats.errorRate * 100))
                        StatRow(label: "Avg Response Time", value: String(format: "%.2fs", stats.averageResponseTime))
                        
                        if !stats.providerUsage.isEmpty {
                            Divider()
                            ForEach(Array(stats.providerUsage.keys.sorted()), id: \.self) { provider in
                                StatRow(label: provider, value: "\(stats.providerUsage[provider] ?? 0)")
                            }
                        }
                    }
                }
                
                // Event Counts
                if let stats = statistics, !stats.eventCounts.isEmpty {
                    Section("Event Counts") {
                        ForEach(Array(stats.eventCounts.keys.sorted()), id: \.self) { eventName in
                            HStack {
                                Text(eventName)
                                Spacer()
                                Text("\(stats.eventCounts[eventName] ?? 0)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Recent Events
                Section("Recent Events") {
                    ForEach(events.prefix(50)) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.name)
                                    .font(.headline)
                                Spacer()
                                Text(event.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !event.properties.isEmpty {
                                Text(propertiesString(event.properties))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Debug Console")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Button(timeframe.rawValue) {
                                selectedTimeframe = timeframe
                                loadData()
                            }
                        }
                    } label: {
                        Text(selectedTimeframe.rawValue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        AnalyticsService.shared.clearEvents()
                        loadData()
                    }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private func loadData() {
        let analytics = AnalyticsService.shared
        let sinceDate = selectedTimeframe.date
        
        events = sinceDate.map { analytics.getEvents(since: $0) } ?? analytics.getRecentEvents(limit: 100)
        statistics = analytics.getStatistics(since: sinceDate)
    }
    
    private func propertiesString(_ properties: [String: Any]) -> String {
        properties.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}

extension AnalyticsEvent: Identifiable {
    var id: Date { timestamp }
}
#endif
