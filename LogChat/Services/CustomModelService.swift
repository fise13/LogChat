//
//  CustomModelService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation

/// Service for managing custom user-added models
@MainActor
class CustomModelService {
    static let shared = CustomModelService()
    
    private let userDefaultsKey = "customLLMModels"
    
    private init() {}
    
    /// Get all custom models
    func getCustomModels() -> [LLMModel] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let models = try? JSONDecoder().decode([LLMModel].self, from: data) else {
            return []
        }
        return models
    }
    
    /// Add a custom model
    func addCustomModel(_ model: LLMModel) {
        var models = getCustomModels()
        
        // Check if model already exists
        if models.contains(where: { $0.id == model.id && $0.provider == model.provider }) {
            return
        }
        
        models.append(model)
        saveCustomModels(models)
    }
    
    /// Remove a custom model
    func removeCustomModel(_ model: LLMModel) {
        var models = getCustomModels()
        models.removeAll { $0.id == model.id && $0.provider == model.provider }
        saveCustomModels(models)
    }
    
    /// Check if model is custom
    func isCustomModel(_ model: LLMModel) -> Bool {
        let customModels = getCustomModels()
        return customModels.contains(where: { $0.id == model.id && $0.provider == model.provider })
    }
    
    private func saveCustomModels(_ models: [LLMModel]) {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            // Post notification for UI updates
            NotificationCenter.default.post(name: NSNotification.Name("CustomModelsUpdated"), object: nil)
        }
    }
}
