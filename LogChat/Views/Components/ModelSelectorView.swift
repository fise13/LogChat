//
//  ModelSelectorView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

#if os(iOS)

struct ModelSelectorView: View {
    @Binding var selectedModel: LLMModel
    let onModelChange: (LLMModel) -> Void
    
    @State private var showModelPicker = false
    @State private var refreshTrigger = false
    
    @MainActor
    private var availableModels: [LLMModel] {
        LLMService.shared.getAvailableModels()
    }
    
    @MainActor
    private var modelsByProvider: [LLMProviderType: [LLMModel]] {
        Dictionary(grouping: availableModels.isEmpty ? LLMModel.allModels : availableModels) { $0.provider }
    }
    
    var body: some View {
        Button {
            showModelPicker = true
        } label: {
            HStack(spacing: 8) {
                // Provider Icon
                Image(systemName: selectedModel.providerIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(selectedModel.providerColorValue)
                    .frame(width: 20, height: 20)
                
                // Model Name
                Text(selectedModel.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                // Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignSystem.Input.background)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(DesignSystem.Input.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(
                selectedModel: $selectedModel,
                onSelect: { model in
                    selectedModel = model
                    onModelChange(model)
                    showModelPicker = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomModelsUpdated"))) { _ in
            refreshTrigger.toggle()
        }
        .onChange(of: refreshTrigger) { _, _ in
            // Refresh will happen automatically via availableModels computed property
        }
    }
}

struct ModelPickerSheet: View {
    @Binding var selectedModel: LLMModel
    let onSelect: (LLMModel) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showAddModel = false
    @State private var refreshTrigger = false
    
    @MainActor
    private var currentModelsByProvider: [LLMProviderType: [LLMModel]] {
        let availableModels = LLMService.shared.getAvailableModels()
        return Dictionary(grouping: availableModels.isEmpty ? LLMModel.allModels : availableModels) { $0.provider }
    }
    
    private var currentProviderOrder: [LLMProviderType] {
        [.openAI, .anthropic, .google, .mistral, .meta, .openRouter]
            .filter { currentModelsByProvider[$0] != nil && !currentModelsByProvider[$0]!.isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Add Model Button
                        Button {
                            showAddModel = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(DesignSystem.Accent.primary)
                                
                                Text("Add Model")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(DesignSystem.Input.background)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignSystem.Accent.primary.opacity(0.3), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        ForEach(currentProviderOrder, id: \.self) { provider in
                            if let models = currentModelsByProvider[provider], !models.isEmpty {
                                ModelProviderSection(
                                    provider: provider,
                                    models: models,
                                    selectedModel: selectedModel,
                                    onSelect: { model in
                                        onSelect(model)
                                    },
                                    onDelete: { model in
                                        CustomModelService.shared.removeCustomModel(model)
                                        refreshTrigger.toggle()
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Accent.primary)
                }
            }
            .sheet(isPresented: $showAddModel) {
                AddModelView { newModel in
                    CustomModelService.shared.addCustomModel(newModel)
                    refreshTrigger.toggle()
                }
            }
            .onChange(of: refreshTrigger) { _, _ in
                // Refresh will happen automatically via currentModelsByProvider computed property
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomModelsUpdated"))) { _ in
                refreshTrigger.toggle()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct ModelProviderSection: View {
    let provider: LLMProviderType
    let models: [LLMModel]
    let selectedModel: LLMModel
    let onSelect: (LLMModel) -> Void
    let onDelete: ((LLMModel) -> Void)?
    
    init(provider: LLMProviderType, models: [LLMModel], selectedModel: LLMModel, onSelect: @escaping (LLMModel) -> Void, onDelete: ((LLMModel) -> Void)? = nil) {
        self.provider = provider
        self.models = models
        self.selectedModel = selectedModel
        self.onSelect = onSelect
        self.onDelete = onDelete
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider Header
            HStack(spacing: 8) {
                Image(systemName: provider.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(provider.colorValue)
                
                Text(provider.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Models
            VStack(spacing: 8) {
                ForEach(models) { model in
                    ModelRowView(
                        model: model,
                        isSelected: model.id == selectedModel.id && model.provider == selectedModel.provider,
                        isCustom: CustomModelService.shared.isCustomModel(model),
                        onSelect: {
                            onSelect(model)
                        },
                        onDelete: onDelete != nil ? {
                            onDelete?(model)
                        } : nil
                    )
                }
            }
        }
    }
}

struct ModelRowView: View {
    let model: LLMModel
    let isSelected: Bool
    let isCustom: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?
    
    init(model: LLMModel, isSelected: Bool, isCustom: Bool = false, onSelect: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.model = model
        self.isSelected = isSelected
        self.isCustom = isCustom
        self.onSelect = onSelect
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    // Selection Indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? DesignSystem.Accent.primary : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        
                        if isSelected {
                            Circle()
                                .fill(DesignSystem.Accent.primary)
                                .frame(width: 14, height: 14)
                        }
                    }
                    
                    // Model Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            if isCustom {
                                Text("Custom")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignSystem.Accent.primary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        
                        if let description = model.description {
                            HStack(spacing: 6) {
                                // Speed Tier Badge
                                SpeedTierBadge(tier: model.speedTier)
                                
                                Text(description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Context Size
                    if let contextLength = model.contextLength {
                        Text(formatContextSize(contextLength))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isSelected ? DesignSystem.Accent.primary.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Delete button for custom models
            if isCustom, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
    }
    
    private func formatContextSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return "\(tokens / 1_000_000)M"
        } else if tokens >= 1_000 {
            return "\(tokens / 1_000)K"
        } else {
            return "\(tokens)"
        }
    }
}

struct SpeedTierBadge: View {
    let tier: LLMModel.SpeedTier
    
    var body: some View {
        Text(tier.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tierColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tierColor.opacity(0.15))
            .cornerRadius(4)
    }
    
    private var tierColor: Color {
        switch tier {
        case .fast:
            return .green
        case .balanced:
            return .blue
        case .smart:
            return .purple
        }
    }
}

// MARK: - Add Model View

struct AddModelView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProvider: LLMProviderType = .openRouter
    @State private var modelId: String = ""
    @State private var modelName: String = ""
    @State private var modelDescription: String = ""
    @State private var contextLength: String = ""
    @State private var speedTier: LLMModel.SpeedTier = .balanced
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onAdd: (LLMModel) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                Form {
                    Section {
                        Picker("Provider", selection: $selectedProvider) {
                            ForEach([LLMProviderType.openRouter, .openAI, .anthropic, .google, .mistral, .meta], id: \.self) { provider in
                                HStack {
                                    Image(systemName: provider.icon)
                                        .foregroundColor(provider.colorValue)
                                    Text(provider.displayName)
                                }
                                .tag(provider)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("Provider")
                    }
                    
                    Section {
                        TextField("Model ID", text: $modelId)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Display Name", text: $modelName)
                        
                        TextField("Description (optional)", text: $modelDescription)
                    } header: {
                        Text("Model Information")
                    } footer: {
                        if selectedProvider == .openRouter {
                            Text("For OpenRouter, use format: provider/model-id (e.g., openai/gpt-4)")
                        } else {
                            Text("Enter the exact model ID from the provider")
                        }
                    }
                    
                    Section {
                        TextField("Context Length (tokens)", text: $contextLength)
                            .keyboardType(.numberPad)
                        
                        Picker("Speed Tier", selection: $speedTier) {
                            Text("Fast").tag(LLMModel.SpeedTier.fast)
                            Text("Balanced").tag(LLMModel.SpeedTier.balanced)
                            Text("Smart").tag(LLMModel.SpeedTier.smart)
                        }
                    } header: {
                        Text("Settings")
                    } footer: {
                        Text("Context length is optional. Leave empty if unknown.")
                    }
                    
                    Section {
                        Button {
                            addModel()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Add Model")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .navigationTitle("Add Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addModel() {
        guard isValid else {
            errorMessage = "Please fill in all required fields"
            showError = true
            return
        }
        
        let trimmedId = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = modelDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : modelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedContextLength = Int(contextLength.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Check if model already exists
        let existingModels = LLMModel.allModels + CustomModelService.shared.getCustomModels()
        if existingModels.contains(where: { $0.id == trimmedId && $0.provider == selectedProvider }) {
            errorMessage = "This model already exists"
            showError = true
            return
        }
        
        let newModel = LLMModel(
            id: trimmedId,
            name: trimmedName,
            provider: selectedProvider,
            contextLength: parsedContextLength,
            description: trimmedDescription,
            speedTier: speedTier
        )
        
        onAdd(newModel)
        dismiss()
    }
}

#else
// macOS placeholder
struct ModelSelectorView: View {
    @Binding var selectedModel: LLMModel
    let onModelChange: (LLMModel) -> Void
    
    var body: some View {
        EmptyView()
    }
}
#endif
