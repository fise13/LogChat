//
//  TemplatesView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData

struct TemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\QueryTemplate.usageCount, order: .reverse)]) private var templates: [QueryTemplate]
    @State private var showingCreateTemplate = false
    @State private var selectedTemplate: QueryTemplate?
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                if templates.isEmpty {
                    EmptyTemplatesView {
                        showingCreateTemplate = true
                    }
                } else {
                    List {
                        ForEach(templates) { template in
                            TemplateRow(template: template) {
                                selectedTemplate = template
                            }
                            .listRowInsets(EdgeInsets(
                                top: 8,
                                leading: DesignSystem.Spacing.md,
                                bottom: 8,
                                trailing: DesignSystem.Spacing.md
                            ))
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignSystem.Background.secondary)
                                    .padding(.vertical, 2)
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteTemplate(template)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Шаблоны")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateTemplate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Accent.primary)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingCreateTemplate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Accent.primary)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingCreateTemplate) {
                CreateTemplateView()
            }
            #if os(iOS)
            .fullScreenCover(item: $selectedTemplate) { template in
                TemplateChatView(template: template)
            }
            #else
            .sheet(item: $selectedTemplate) { template in
                TemplateChatView(template: template)
            }
            #endif
        }
    }
    
    private func deleteTemplate(_ template: QueryTemplate) {
        modelContext.delete(template)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting template: \(error)")
        }
    }
}

struct TemplateRow: View {
    let template: QueryTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if template.usageCount > 0 {
                        Label("\(template.usageCount)", systemImage: "arrow.clockwise")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(template.content)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    if !template.category.isEmpty {
                        Text(template.category)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Accent.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Accent.primary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct EmptyTemplatesView: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(DesignSystem.Accent.primary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Нет шаблонов")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.primary)
                
                Text("Создайте шаблоны для быстрого доступа к частым запросам")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onCreate) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Создать шаблон")
                }
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(DesignSystem.Accent.primary)
                .cornerRadius(12)
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

struct CreateTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var category: String = "general"
    @State private var mode: AIMode = .daily
    
    private let categories = ["general", "work", "code", "planning", "writing", "learning"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title)
                    TextField("Содержимое шаблона", text: $content, axis: .vertical)
                        .lineLimit(5...10)
                } header: {
                    Text("Основное")
                }
                
                Section {
                    Picker("Категория", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat.capitalized).tag(cat)
                        }
                    }
                    
                    Picker("Режим", selection: $mode) {
                        ForEach(AIMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.icon).tag(mode)
                        }
                    }
                } header: {
                    Text("Настройки")
                }
            }
            .navigationTitle("Новый шаблон")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать") {
                        createTemplate()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        createTemplate()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
                #endif
            }
        }
    }
    
    private func createTemplate() {
        let template = QueryTemplate(
            title: title,
            content: content,
            mode: mode.rawValue,
            category: category
        )
        modelContext.insert(template)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error creating template: \(error)")
        }
    }
}

struct TemplateChatView: View {
    let template: QueryTemplate
    @Environment(\.dismiss) var dismiss
    
    var mode: AIMode {
        AIMode.allCases.first(where: { $0.rawValue == template.mode }) ?? .daily
    }
    
    var body: some View {
        ChatView(chat: nil, initialMode: mode, initialPrompt: template.content)
            .navigationTitle(template.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        updateUsageCount()
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Готово") {
                        updateUsageCount()
                        dismiss()
                    }
                }
                #endif
            }
    }
    
    private func updateUsageCount() {
        template.usageCount += 1
        do {
            try template.modelContext?.save()
        } catch {
            print("Error updating template usage: \(error)")
        }
    }
}

