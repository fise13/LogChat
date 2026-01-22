//
//  OnboardingView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var selectedLanguage = "Russian"
    @State private var openRouterKey = ""
    @State private var enableMemory = true
    @State private var enableAutoSuggestions = true
    @State private var selectedModel: LLMModel?
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let totalSteps = 4
    
    var body: some View {
        ZStack {
            DesignSystem.Background.primary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .tint(DesignSystem.Accent.primary)
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Content - use conditional view instead of TabView for better interaction control
                Group {
                    switch currentStep {
                    case 0:
                        WelcomeStep()
                    case 1:
                        LanguageStep(selectedLanguage: $selectedLanguage)
                    case 2:
                        APIKeyStep(openRouterKey: $openRouterKey, showError: $showError, errorMessage: $errorMessage)
                    case 3:
                        SetupStep(
                            enableMemory: $enableMemory,
                            enableAutoSuggestions: $enableAutoSuggestions,
                            selectedModel: $selectedModel
                        )
                    default:
                        WelcomeStep()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == totalSteps - 1 ? "Complete" : "Next") {
                        handleNext()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignSystem.Accent.primary)
                    .disabled(currentStep == 2 && openRouterKey.isEmpty && !validateAPIKey())
                }
                .padding()
            }
        }
    }
    
    private func handleNext() {
        if currentStep == 2 {
            // Validate API key
            if openRouterKey.isEmpty || !validateAPIKey() {
                showError = true
                errorMessage = "Please enter a valid OpenRouter API key"
                return
            }
        }
        
        if currentStep == totalSteps - 1 {
            completeOnboarding()
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    private func validateAPIKey() -> Bool {
        // Basic validation - key should not be empty and should look like a key
        return !openRouterKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func completeOnboarding() {
        // Save API key
        if !openRouterKey.isEmpty {
            LLMService.shared.setAPIKey(openRouterKey.trimmingCharacters(in: .whitespaces), for: .openRouter)
        }
        
        // Save settings
        UserDefaults.standard.set(enableMemory, forKey: "memoryEnabled")
        UserDefaults.standard.set(enableAutoSuggestions, forKey: "autoMemorySuggestionsEnabled")
        
        // Set default model if selected
        if let model = selectedModel {
            UserDefaults.standard.set(model.id, forKey: "defaultModelId")
            UserDefaults.standard.set(model.provider.rawValue, forKey: "defaultModelProvider")
        }
        
        // Initialize default workspace
        let _ = WorkspaceService.shared.getDefaultWorkspace(context: modelContext)
        
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        
        dismiss()
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(DesignSystem.Accent.primary)
            
            VStack(spacing: 12) {
                Text("Welcome to LogChat")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Your AI assistant with memory")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "sparkles", title: "Multiple LLMs", description: "ChatGPT, Claude, Gemini, and more")
                FeatureRow(icon: "brain.head.profile", title: "Persistent Memory", description: "Remember important facts about you")
                FeatureRow(icon: "lock.fill", title: "Secure & Private", description: "Your data stays on your device")
                FeatureRow(icon: "person.fill", title: "Personalized", description: "Tailored responses based on your preferences")
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(DesignSystem.Accent.primary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Language Step

struct LanguageStep: View {
    @Binding var selectedLanguage: String
    
    private let languages = ["Russian", "English", "Auto-detect"]
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Accent.primary)
            
            VStack(spacing: 12) {
                Text("Choose Language")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Select your preferred language for the interface")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                ForEach(languages, id: \.self) { language in
                    Button {
                        withAnimation {
                            selectedLanguage = language
                        }
                    } label: {
                        HStack {
                            Text(language)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Accent.primary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedLanguage == language ? DesignSystem.Accent.primary.opacity(0.1) : DesignSystem.Background.secondary)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - API Key Step

struct APIKeyStep: View {
    @Binding var openRouterKey: String
    @Binding var showError: Bool
    @Binding var errorMessage: String
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Accent.primary)
            
            VStack(spacing: 12) {
                Text("API Key Setup")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Enter your OpenRouter API key to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                TextField("OpenRouter API Key", text: $openRouterKey)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit {
                        // Handle submit if needed
                    }
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Link("Get your API key from OpenRouter", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Accent.primary)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Setup Step

struct SetupStep: View {
    @Binding var enableMemory: Bool
    @Binding var enableAutoSuggestions: Bool
    @Binding var selectedModel: LLMModel?
    
    private let availableModels = LLMModel.allModels.filter { $0.provider == .openRouter }.prefix(3)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Accent.primary)
                
                VStack(spacing: 12) {
                    Text("Final Setup")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Configure your preferences")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    // Memory toggle
                    Toggle(isOn: $enableMemory) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Memory")
                                .font(.headline)
                            Text("Remember important facts about you")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if enableMemory {
                        Toggle(isOn: $enableAutoSuggestions) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto Memory Suggestions")
                                    .font(.headline)
                                Text("AI suggests what to remember")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Default model
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Model")
                            .font(.headline)
                        
                        ForEach(Array(availableModels), id: \.id) { model in
                            Button {
                                selectedModel = model
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.name)
                                            .foregroundColor(.primary)
                                        Text(model.description ?? "")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedModel?.id == model.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(DesignSystem.Accent.primary)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedModel?.id == model.id ? DesignSystem.Accent.primary.opacity(0.1) : DesignSystem.Background.secondary)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}
