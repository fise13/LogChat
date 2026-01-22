//
//  NotesView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData

// TagChip вынесен в отдельный файл TagChipView.swift

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]) private var allNotes: [Note]
    
    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    @State private var showingCreateNote = false
    
    private var filteredNotes: [Note] {
        var notes = allNotes
        
        // Сортируем: сначала закрепленные, затем по дате обновления
        notes = notes.sorted { note1, note2 in
            if note1.isPinned != note2.isPinned {
                return note1.isPinned
            }
            return note1.updatedAt > note2.updatedAt
        }
        
        // Фильтр по поиску
        if !searchText.isEmpty {
            notes = notes.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Фильтр по тегу
        if let tag = selectedTag {
            notes = notes.filter { $0.tags.contains(tag) }
        }
        
        return notes
    }
    
    private var allTags: [String] {
        Array(Set(allNotes.flatMap { $0.tags })).sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                if filteredNotes.isEmpty {
                    EmptyNotesView {
                        showingCreateNote = true
                    }
                } else {
                    VStack(spacing: 0) {
                        // Теги фильтр
                        if !allTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    TagChip(
                                        title: "Все",
                                        isSelected: selectedTag == nil,
                                        color: DesignSystem.Accent.primary
                                    ) {
                                        selectedTag = nil
                                    }
                                    
                                    ForEach(allTags, id: \.self) { tag in
                                        TagChip(
                                            title: tag,
                                            isSelected: selectedTag == tag,
                                            color: getTagColor(tag)
                                        ) {
                                            selectedTag = selectedTag == tag ? nil : tag
                                        }
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                            }
                            .background(DesignSystem.Background.secondary)
                        }
                        
                        List {
                            ForEach(filteredNotes) { note in
                                NavigationLink {
                                    NoteDetailView(note: note)
                                } label: {
                                    NoteRow(note: note)
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
                            }
                            .onDelete(perform: deleteNotes)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Заметки")
            .searchable(text: $searchText, prompt: "Поиск заметок")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateNote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Accent.primary)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingCreateNote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Accent.primary)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingCreateNote) {
                CreateNoteView()
            }
        }
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = filteredNotes[index]
            modelContext.delete(note)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    private func getTagColor(_ tag: String) -> Color {
        let colors: [Color] = [
            DesignSystem.Accent.primary,
            DesignSystem.Accent.secondary,
            DesignSystem.Accent.success,
            DesignSystem.Accent.warning,
            .purple,
            .pink
        ]
        let index = abs(tag.hashValue) % colors.count
        return colors[index]
    }
}

struct NoteRow: View {
    let note: Note
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Цветной индикатор
            RoundedRectangle(cornerRadius: 4)
                .fill(note.color.color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(note.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Accent.warning)
                    }
                    
                    Spacer()
                    
                    Text(note.updatedAt, style: .relative)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(note.content)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(DesignSystem.Typography.caption2)
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignSystem.Accent.primary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}


struct EmptyNotesView: View {
    let onCreate: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "note.text")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(DesignSystem.Accent.primary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Нет заметок")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(.primary)
                
                Text("Сохраняйте идеи, мысли и важную информацию")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onCreate) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Создать заметку")
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

struct CreateNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var selectedColor: NoteColor = .default
    @State private var isPinned: Bool = false
    
    private let availableColors = NoteColor.allCases
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title)
                    TextField("Содержимое", text: $content, axis: .vertical)
                        .lineLimit(5...15)
                } header: {
                    Text("Основное")
                }
                
                Section {
                    HStack {
                        Text("Цвет")
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(availableColors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    }
                    
                    Toggle("Закрепить", isOn: $isPinned)
                } header: {
                    Text("Настройки")
                }
                
                Section {
                    HStack {
                        TextField("Новый тег", text: $newTag)
                            .onSubmit {
                                addTag()
                            }
                        Button("Добавить") {
                            addTag()
                        }
                        .disabled(newTag.isEmpty)
                    }
                    
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(DesignSystem.Typography.caption)
                                        Button {
                                            tags.removeAll { $0 == tag }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(DesignSystem.Accent.primary.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Теги")
                }
            }
            .navigationTitle("Новая заметка")
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
                    Button("Сохранить") {
                        createNote()
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
                    Button("Сохранить") {
                        createNote()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
                #endif
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }
    
    private func createNote() {
        let note = Note(
            title: title,
            content: content,
            tags: tags,
            isPinned: isPinned,
            color: selectedColor
        )
        modelContext.insert(note)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error creating note: \(error)")
        }
    }
}

struct NoteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note
    @State private var isEditing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.title)
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(.primary)
                
                Text(note.content)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(DesignSystem.Accent.primary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Text("Создано: \(note.createdAt, style: .date)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Background.primary)
        .navigationTitle("Заметка")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        note.isPinned.toggle()
                        save()
                    } label: {
                        Label(
                            note.isPinned ? "Открепить" : "Закрепить",
                            systemImage: note.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    
                    Button(role: .destructive) {
                        deleteNote()
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        note.isPinned.toggle()
                        save()
                    } label: {
                        Label(
                            note.isPinned ? "Открепить" : "Закрепить",
                            systemImage: note.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    
                    Button(role: .destructive) {
                        deleteNote()
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            #endif
        }
    }
    
    private func save() {
        note.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            print("Error saving note: \(error)")
        }
    }
    
    private func deleteNote() {
        modelContext.delete(note)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
}

