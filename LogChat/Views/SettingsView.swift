//
//  SettingsView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("openRouterAPIKey") private var apiKey: String = "" // Backward compatibility
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    @AppStorage("anonymizeData") private var anonymizeData: Bool = false
    @AppStorage("incognitoMode") private var incognitoMode: Bool = false
    @AppStorage("contextTokenLimit") private var contextTokenLimit: Int = 8000
    
    @State private var showAPIKeys: [LLMProviderType: Bool] = [:]
    @State private var apiKeys: [LLMProviderType: String] = [:]
    @State private var showSearchAPIKey: Bool = false
    @State private var defaultModelId: String = ""
    @State private var defaultModelProvider: String = ""
    
    private let llmService = LLMService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Background.primary
                    .ignoresSafeArea()
                
                Form {
                    // API Key - OpenRouter (Primary)
                    Section {
                        ProviderAPIKeyRow(
                            provider: .openRouter,
                            apiKey: Binding(
                                get: { apiKeys[.openRouter] ?? "" },
                                set: { newValue in
                                    apiKeys[.openRouter] = newValue
                                    llmService.setAPIKey(newValue, for: .openRouter)
                                }
                            ),
                            showAPIKey: Binding(
                                get: { showAPIKeys[.openRouter] ?? false },
                                set: { showAPIKeys[.openRouter] = $0 }
                            )
                        )
                    } header: {
                        Label("API Key", systemImage: "key.fill")
                            .font(DesignSystem.Typography.headline)
                    } footer: {
                        Text("Get your API key at openrouter.ai. OpenRouter provides access to multiple AI models.")
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    // Additional Providers (Optional)
                    Section {
                        AdditionalProvidersView(
                            apiKeys: $apiKeys,
                            showAPIKeys: $showAPIKeys,
                            llmService: llmService
                        )
                    } header: {
                        Label("Additional Providers (Optional)", systemImage: "plus.circle")
                            .font(DesignSystem.Typography.headline)
                    } footer: {
                        Text("Add direct API keys for OpenAI, Anthropic, or Google to use their models directly.")
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    // Models & Default Selection
                    Section {
                        ModelsManagementView(
                            defaultModelId: $defaultModelId,
                            defaultModelProvider: $defaultModelProvider
                        )
                    } header: {
                        Label("Models", systemImage: "brain")
                            .font(DesignSystem.Typography.headline)
                    } footer: {
                        Text("Add custom models using + button. Select default model for new chats.")
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    Section {
                        HStack {
                            Image(systemName: "faceid")
                                .foregroundColor(DesignSystem.Accent.primary)
                                .frame(width: 24)
                            Toggle("Biometric Authentication", isOn: $biometricEnabled)
                                .onChange(of: biometricEnabled) { _, enabled in
                                    if enabled {
                                        SecurityService.shared.authenticateWithBiometrics { success, _ in
                                            if !success {
                                                biometricEnabled = false
                                            }
                                        }
                                    }
                                }
                        }
                        
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(DesignSystem.Accent.primary)
                                .frame(width: 24)
                            Toggle("Anonymize Data", isOn: $anonymizeData)
                                .onChange(of: anonymizeData) { _, enabled in
                                    SecurityService.shared.anonymizeData = enabled
                                }
                        }
                        
                        HStack {
                            Image(systemName: "eye.trianglebadge.exclamationmark")
                                .foregroundColor(DesignSystem.Accent.primary)
                                .frame(width: 24)
                            Toggle("Incognito Mode", isOn: $incognitoMode)
                        }
                    } header: {
                        Label("Privacy", systemImage: "lock.shield")
                            .font(DesignSystem.Typography.headline)
                    } footer: {
                        Text("Incognito mode doesn't save chat history")
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "number.circle.fill")
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .frame(width: 24)
                                Text("Context Token Limit: \(contextTokenLimit)")
                                    .font(DesignSystem.Typography.body)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(contextTokenLimit) },
                                set: { contextTokenLimit = Int($0) }
                            ), in: 1000...32000, step: 1000)
                            .tint(DesignSystem.Accent.primary)
                            
                            HStack {
                                Text("1K")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("32K")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Label("Context", systemImage: "brain")
                            .font(DesignSystem.Typography.headline)
                    }
                    
                    Section {
                        NavigationLink(destination: MemoryView()) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .frame(width: 24)
                                Text("My Memory")
                                    .font(DesignSystem.Typography.body)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(DesignSystem.Accent.primary)
                                .frame(width: 24)
                            Toggle("Auto Memory Suggestions", isOn: Binding(
                                get: { UserDefaults.standard.bool(forKey: "autoMemorySuggestionsEnabled") },
                                set: { UserDefaults.standard.set($0, forKey: "autoMemorySuggestionsEnabled") }
                            ))
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(DesignSystem.Accent.primary)
                                    .frame(width: 24)
                                Text("Minimum Importance Threshold: \(MemoryImportanceService.shared.getMinimumImportanceThreshold())")
                                    .font(DesignSystem.Typography.body)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(MemoryImportanceService.shared.getMinimumImportanceThreshold()) },
                                set: { newValue in
                                    let threshold = Int(newValue)
                                    UserDefaults.standard.set(threshold, forKey: "memoryMinImportanceThreshold")
                                }
                            ), in: 1...5, step: 1)
                            .tint(DesignSystem.Accent.primary)
                            
                            HStack {
                                Text("1 (All)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("5 (Important Only)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Label("Memory", systemImage: "brain")
                            .font(DesignSystem.Typography.headline)
                    } footer: {
                        Text("AI will suggest important facts to remember. View and manage memories above. Only memories above the threshold are used in conversations.")
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    Section {
                        WebSearchSettingsView(
                            showSearchAPIKey: $showSearchAPIKey
                        )
                    } header: {
                        Label("Web Search", systemImage: "magnifyingglass")
                            .font(DesignSystem.Typography.headline)
                    } footer: {
                        Text("Get API keys: Serper.dev (google.serper.dev) or ContextualWeb (rapidapi.com)")
                            .font(DesignSystem.Typography.caption)
                    }
                    
                    Section {
                        Link(destination: URL(string: "https://openrouter.ai")!) {
                            HStack {
                                Text("OpenRouter.ai")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Links")
                    }
                    
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.8.0")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("About")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Accent.primary,
                                        DesignSystem.Accent.primary.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                NotificationService.shared.requestAuthorization()
                
                // Load API keys from Keychain
                // Primary: OpenRouter
                apiKeys[.openRouter] = llmService.getAPIKey(for: .openRouter) ?? ""
                // Additional providers (only load if configured)
                for provider in [LLMProviderType.openAI, .anthropic, .google] {
                    if let key = llmService.getAPIKey(for: provider), !key.isEmpty {
                        apiKeys[provider] = key
                    }
                }
                
                // Load default model (prefer OpenRouter)
                if let modelId = UserDefaults.standard.string(forKey: "defaultModelId"),
                   let providerRaw = UserDefaults.standard.string(forKey: "defaultModelProvider") {
                    defaultModelId = modelId
                    defaultModelProvider = providerRaw
                } else {
                    // Default to OpenRouter
                    let defaultModel = LLMModel.defaultModel
                    defaultModelId = defaultModel.id
                    defaultModelProvider = defaultModel.provider.rawValue
                    // Save as default
                    UserDefaults.standard.set(defaultModelId, forKey: "defaultModelId")
                    UserDefaults.standard.set(defaultModelProvider, forKey: "defaultModelProvider")
                }
                
                // Backward compatibility: migrate old OpenRouter key
                if !apiKey.isEmpty && apiKeys[.openRouter]?.isEmpty != false {
                    llmService.setAPIKey(apiKey, for: .openRouter)
                    apiKeys[.openRouter] = apiKey
                }
            }
            .onChange(of: apiKey) { _, newValue in
                // Backward compatibility
                if !newValue.isEmpty {
                    llmService.setAPIKey(newValue, for: .openRouter)
                    apiKeys[.openRouter] = newValue
                }
            }
            .onChange(of: defaultModelId) { _, _ in
                UserDefaults.standard.set(defaultModelId, forKey: "defaultModelId")
                UserDefaults.standard.set(defaultModelProvider, forKey: "defaultModelProvider")
            }
            .onChange(of: defaultModelProvider) { _, _ in
                UserDefaults.standard.set(defaultModelId, forKey: "defaultModelId")
                UserDefaults.standard.set(defaultModelProvider, forKey: "defaultModelProvider")
            }
            .onChange(of: contextTokenLimit) { _, _ in
                // Синхронизируем настройки с Firebase
                if FirebaseService.shared.isFirebaseAvailable {
                    Task {
                        try? await FirebaseService.shared.syncSettings()
                    }
                }
            }
            .onChange(of: biometricEnabled) { _, _ in
                if FirebaseService.shared.isFirebaseAvailable {
                    Task {
                        try? await FirebaseService.shared.syncSettings()
                    }
                }
            }
            .onChange(of: anonymizeData) { _, _ in
                if FirebaseService.shared.isFirebaseAvailable {
                    Task {
                        try? await FirebaseService.shared.syncSettings()
                    }
                }
            }
            .onChange(of: incognitoMode) { _, _ in
                if FirebaseService.shared.isFirebaseAvailable {
                    Task {
                        try? await FirebaseService.shared.syncSettings()
                    }
                }
            }
        }
    }
}

// MARK: - Provider API Key Row

struct ProviderAPIKeyRow: View {
    let provider: LLMProviderType
    @Binding var apiKey: String
    @Binding var showAPIKey: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Provider Icon
            Image(systemName: provider.icon)
                .foregroundColor(provider.colorValue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if showAPIKey {
                    TextField("Enter API key", text: $apiKey)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                        .font(.system(size: 14))
                } else {
                    SecureField("Enter API key", text: $apiKey)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                        .font(.system(size: 14))
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    showAPIKey.toggle()
                }
            } label: {
                Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Additional Providers View

struct AdditionalProvidersView: View {
    @Binding var apiKeys: [LLMProviderType: String]
    @Binding var showAPIKeys: [LLMProviderType: Bool]
    let llmService: LLMService
    
    @State private var expandedProviders: Set<LLMProviderType> = []
    
    private let additionalProviders: [LLMProviderType] = [.openAI, .anthropic, .google]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(additionalProviders, id: \.self) { provider in
                let hasKey = !(apiKeys[provider]?.isEmpty ?? true)
                
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedProviders.contains(provider) {
                                expandedProviders.remove(provider)
                            } else {
                                expandedProviders.insert(provider)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: provider.icon)
                                .foregroundColor(provider.colorValue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if hasKey {
                                    Text("Configured")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: expandedProviders.contains(provider) ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if expandedProviders.contains(provider) {
                        VStack(spacing: 8) {
                            Divider()
                            
                            HStack(spacing: 12) {
                                if showAPIKeys[provider] ?? false {
                                    TextField("Enter API key", text: Binding(
                                        get: { apiKeys[provider] ?? "" },
                                        set: { newValue in
                                            apiKeys[provider] = newValue
                                            llmService.setAPIKey(newValue, for: provider)
                                        }
                                    ))
                                    .textFieldStyle(.plain)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(.system(size: 14))
                                } else {
                                    SecureField("Enter API key", text: Binding(
                                        get: { apiKeys[provider] ?? "" },
                                        set: { newValue in
                                            apiKeys[provider] = newValue
                                            llmService.setAPIKey(newValue, for: provider)
                                        }
                                    ))
                                    .textFieldStyle(.plain)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .font(.system(size: 14))
                                }
                                
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAPIKeys[provider, default: false].toggle()
                                    }
                                } label: {
                                    Image(systemName: showAPIKeys[provider] ?? false ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(.bottom, 12)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                if provider != additionalProviders.last {
                    Divider()
                }
            }
        }
    }
}

// MARK: - Models Management View

struct ModelsManagementView: View {
    @Binding var defaultModelId: String
    @Binding var defaultModelProvider: String
    @State private var showAddModel = false
    @State private var refreshTrigger = false
    
    @MainActor
    private var availableModels: [LLMModel] {
        LLMService.shared.getAvailableModels()
    }
    
    private var selectedModel: LLMModel? {
        guard let provider = LLMProviderType(rawValue: defaultModelProvider) else {
            return nil
        }
        return availableModels.first { $0.id == defaultModelId && $0.provider == provider }
            ?? LLMModel.allModels.first { $0.id == defaultModelId && $0.provider == provider }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Add Model Button
            Button {
                showAddModel = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Accent.primary)
                    
                    Text("Add Custom Model")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(DesignSystem.Input.background)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignSystem.Accent.primary.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            
            // Default Model Selector
            if !availableModels.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Default Model")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let selected = selectedModel {
                            HStack(spacing: 6) {
                                Image(systemName: selected.providerIcon)
                                    .foregroundColor(selected.providerColorValue)
                                    .font(.system(size: 12))
                                Text(selected.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Picker("Default Model", selection: Binding(
                        get: {
                            if let model = selectedModel {
                                return "\(model.provider.rawValue):\(model.id)"
                            }
                            return "\(LLMModel.defaultModel.provider.rawValue):\(LLMModel.defaultModel.id)"
                        },
                        set: { value in
                            let parts = value.split(separator: ":")
                            if parts.count == 2 {
                                defaultModelProvider = String(parts[0])
                                defaultModelId = String(parts[1])
                            }
                        }
                    )) {
                        ForEach(availableModels.sorted(by: { $0.provider.rawValue < $1.provider.rawValue })) { model in
                            HStack {
                                Image(systemName: model.providerIcon)
                                    .foregroundColor(model.providerColorValue)
                                Text(model.displayName)
                                if let desc = model.description {
                                    Text("(\(desc))")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 13))
                                }
                                Spacer()
                                if model.id == defaultModelId && model.provider.rawValue == defaultModelProvider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignSystem.Accent.primary)
                                }
                            }
                            .tag("\(model.provider.rawValue):\(model.id)")
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No models available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Add your OpenRouter API key above and models will appear here")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .sheet(isPresented: $showAddModel) {
            AddModelView { newModel in
                CustomModelService.shared.addCustomModel(newModel)
                refreshTrigger.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomModelsUpdated"))) { _ in
            refreshTrigger.toggle()
        }
        .onChange(of: refreshTrigger) { _, _ in
            // Force refresh
        }
    }
}

// MARK: - Web Search Settings View

struct WebSearchSettingsView: View {
    @Binding var showSearchAPIKey: Bool
    @State private var apiKey: String = ""
    @State private var provider: String = "serper"
    @State private var isTesting: Bool = false
    @State private var testStatus: TestStatus? = nil
    
    enum TestStatus {
        case success
        case failure(String)
        
        var color: Color {
            switch self {
            case .success: return .green
            case .failure: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            }
        }
        
        var message: String {
            switch self {
            case .success: return "API key is valid"
            case .failure(let error): return error
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // API Key Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Accent.primary)
                    .frame(width: 24)
                
                if showSearchAPIKey {
                    TextField("Enter Search API key", text: $apiKey)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                        .onChange(of: apiKey) { _, newValue in
                            SearchService.shared.updateAPIKey(newValue)
                            testStatus = nil
                        }
                } else {
                    SecureField("Enter Search API key", text: $apiKey)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                        .onChange(of: apiKey) { _, newValue in
                            SearchService.shared.updateAPIKey(newValue)
                            testStatus = nil
                        }
                }
                
                Button {
                    withAnimation(DesignSystem.Animation.quick) {
                        showSearchAPIKey.toggle()
                    }
                } label: {
                    Image(systemName: showSearchAPIKey ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
            
            // Test Button & Status
            HStack {
                Button {
                    Task {
                        await testAPIKey()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text(isTesting ? "Testing..." : "Test API Key")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Accent.primary)
                    )
                }
                .disabled(isTesting || apiKey.isEmpty)
                .opacity(apiKey.isEmpty ? 0.5 : 1.0)
                
                if let status = testStatus {
                    HStack(spacing: 6) {
                        Image(systemName: status.icon)
                            .foregroundColor(status.color)
                            .font(.system(size: 14))
                        Text(status.message)
                            .font(.system(size: 13))
                            .foregroundColor(status.color)
                    }
                }
                
                Spacer()
            }
            
            // Provider Selection
            Picker("Search Provider", selection: $provider) {
                Text("Serper.dev").tag("serper")
                Text("ContextualWeb").tag("contextualweb")
            }
            .pickerStyle(.menu)
            .onChange(of: provider) { _, newValue in
                SearchService.shared.updateProvider(newValue)
                testStatus = nil
            }
            
            // Status Indicator
            HStack {
                let isConfigured = !apiKey.isEmpty
                Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(isConfigured ? .green : .orange)
                    .font(.system(size: 12))
                
                Text(isConfigured ? "Web search is configured" : "Web search is not configured")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "searchAPIKey") ?? ""
            provider = UserDefaults.standard.string(forKey: "searchProvider") ?? "serper"
        }
    }
    
    @MainActor
    private func testAPIKey() async {
        isTesting = true
        testStatus = nil
        
        let isValid = await SearchService.shared.testAPIKey()
        
        isTesting = false
        
        if isValid {
            testStatus = .success
        } else {
            let currentKey = UserDefaults.standard.string(forKey: "searchAPIKey") ?? ""
            if currentKey.isEmpty {
                testStatus = .failure("API key is empty")
            } else {
                testStatus = .failure("Invalid API key or network error")
            }
        }
        
        // Clear status after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            testStatus = nil
        }
    }
}
