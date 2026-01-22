//
//  MemoryView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData

struct MemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\MemoryItem.importance, order: .reverse), SortDescriptor(\MemoryItem.updatedAt, order: .reverse)]) private var allMemories: [MemoryItem]
    
    @State private var selectedType: MemoryType? = nil
    @State private var showingDeleteAlert = false
    @State private var memoryToDelete: MemoryItem?
    @State private var minImportanceFilter: Int = MemoryImportanceService.shared.getMinimumImportanceThreshold()
    
    private var filteredMemories: [MemoryItem] {
        let minImportance = MemoryImportanceService.shared.getMinimumImportanceThreshold()
        var filtered = allMemories.filter { $0.importance >= minImportance }
        
        guard let type = selectedType else {
            return filtered
        }
        return filtered.filter { $0.memoryType == type }
    }
    
    private var memoriesByType: [MemoryType: [MemoryItem]] {
        let filtered = filteredMemories
        return Dictionary(grouping: filtered) { item in
            item.memoryType
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                if allMemories.isEmpty {
                    EmptyMemoryView()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Filter by type
                            if !allMemories.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        FilterChip(
                                            title: "All",
                                            isSelected: selectedType == nil,
                                            action: { selectedType = nil }
                                        )
                                        
                                        ForEach(MemoryType.allCases, id: \.self) { type in
                                            FilterChip(
                                                title: type.displayName,
                                                icon: type.icon,
                                                isSelected: selectedType == type,
                                                action: { selectedType = type }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                }
                                .padding(.vertical, DesignSystem.Spacing.sm)
                            }
                            
                            // Memories grouped by type
                            VStack(spacing: 20) {
                                ForEach(MemoryType.allCases, id: \.self) { type in
                                    if let memories = memoriesByType[type], !memories.isEmpty {
                                        MemorySection(
                                            type: type,
                                            memories: memories,
                                            onDelete: { memory in
                                                memoryToDelete = memory
                                                showingDeleteAlert = true
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
            .navigationTitle("My Memory")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NeoChatLogoView(size: .small, showText: false)
                }
            }
            .alert("Delete Memory", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let memory = memoryToDelete {
                        MemoryService.shared.deleteMemory(context: modelContext, memory: memory)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this memory? This action cannot be undone.")
            }
            .onAppear {
                // Perform memory maintenance when viewing memory
                MemoryService.shared.performMemoryMaintenance(context: modelContext)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? DesignSystem.Accent.primary : DesignSystem.Background.secondary)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .buttonStyle(.plain)
    }
}

struct MemorySection: View {
    let type: MemoryType
    let memories: [MemoryItem]
    let onDelete: (MemoryItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(type.displayName, systemImage: type.icon)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(memories.count)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Background.secondary)
                    .cornerRadius(DesignSystem.CornerRadius.small)
            }
            
                        VStack(spacing: 8) {
                ForEach(memories) { memory in
                    MemoryRowView(
                        memory: memory,
                        minImportance: MemoryImportanceService.shared.getMinimumImportanceThreshold(),
                        onDelete: { onDelete(memory) }
                    )
                }
            }
        }
    }
}

struct MemoryRowView: View {
    @Bindable var memory: MemoryItem
    let minImportance: Int
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(memory.key)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Importance indicator with score
                HStack(spacing: 6) {
                    // Visual stars
                    HStack(spacing: 3) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < (memory.importance / 2) ? "star.fill" : "star")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(index < (memory.importance / 2) ? importanceColor : Color.secondary.opacity(0.3))
                        }
                    }
                    
                    // Score text
                    Text("\(memory.importance)/10")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(importanceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(importanceColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            
            Text(memory.content)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text(memory.updatedAt, style: .relative)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
                
                if memory.usageCount > 0 {
                    Text("• Used \(memory.usageCount) times")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Accent.danger)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Background.secondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
        .opacity(memory.importance < minImportance ? 0.5 : 1.0)
    }
    
    private var importanceColor: Color {
        switch memory.importance {
        case 8...10:
            return .green
        case 6...7:
            return .blue
        case 4...5:
            return .orange
        default:
            return .red
        }
    }
}

struct EmptyMemoryView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Accent.primary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(DesignSystem.Accent.primary.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                Text("No memories yet")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.primary)
                
                Text("As you chat, NeoChat will learn about you and save important information to provide better, personalized responses.")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }
}


