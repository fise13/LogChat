//
//  SecurityService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import LocalAuthentication
import CryptoKit
import Security

class SecurityService {
    static let shared = SecurityService()
    
    // MARK: - Биометрическая аутентификация
    
    func authenticateWithBiometrics(completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Подтвердите вашу личность для доступа к приложению"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        } else {
            completion(false, error)
        }
    }
    
    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricEnabled") }
    }
    
    // MARK: - Шифрование данных
    
    func encrypt(_ data: Data) -> Data? {
        // Используем симметричное шифрование
        let key = SymmetricKey(size: .bits256)
        return try? AES.GCM.seal(data, using: key).combined
    }
    
    func decrypt(_ encryptedData: Data) -> Data? {
        // В реальном приложении нужно сохранять ключ в Keychain
        // Здесь упрощенная версия
        return encryptedData
    }
    
    // MARK: - Анонимизация данных
    
    func anonymizeText(_ text: String) -> String {
        var anonymized = text
        
        // Удаляем email адреса
        let emailPattern = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        anonymized = anonymized.replacingOccurrences(of: emailPattern, with: "[EMAIL]", options: .regularExpression)
        
        // Удаляем телефонные номера
        let phonePattern = #"\+?[\d\s\-\(\)]{10,}"#
        anonymized = anonymized.replacingOccurrences(of: phonePattern, with: "[PHONE]", options: .regularExpression)
        
        // Удаляем IP адреса
        let ipPattern = #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"#
        anonymized = anonymized.replacingOccurrences(of: ipPattern, with: "[IP]", options: .regularExpression)
        
        return anonymized
    }
    
    // MARK: - Настройки приватности
    
    var anonymizeData: Bool {
        get { UserDefaults.standard.bool(forKey: "anonymizeData") }
        set { UserDefaults.standard.set(newValue, forKey: "anonymizeData") }
    }
    
    var autoDeleteAfterDays: Int {
        get { 
            let days = UserDefaults.standard.integer(forKey: "autoDeleteAfterDays")
            return days > 0 ? days : 0 // 0 = не удалять
        }
        set { UserDefaults.standard.set(newValue, forKey: "autoDeleteAfterDays") }
    }
    
    // MARK: - Keychain Support
    
    private let service = "com.logchat.apiKeys"
    
    /// Save API key to Keychain
    func saveAPIKey(_ key: String, forProvider provider: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Get API key from Keychain
    func getAPIKey(forProvider provider: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Delete API key from Keychain
    func deleteAPIKey(forProvider provider: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if API key exists in Keychain
    func hasAPIKey(forProvider provider: String) -> Bool {
        return getAPIKey(forProvider: provider) != nil
    }
    
    // MARK: - Secure Mode
    
    /// Secure mode: enhanced privacy settings
    var secureMode: Bool {
        get { UserDefaults.standard.bool(forKey: "secureMode") }
        set { UserDefaults.standard.set(newValue, forKey: "secureMode") }
    }
    
    /// Should encrypt sensitive memories
    var encryptSensitiveMemories: Bool {
        get { UserDefaults.standard.bool(forKey: "encryptSensitiveMemories") }
        set { UserDefaults.standard.set(newValue, forKey: "encryptSensitiveMemories") }
    }
    
    /// Enhanced deletion rules for secure mode
    func shouldDeleteInSecureMode(age: TimeInterval) -> Bool {
        guard secureMode else { return false }
        // In secure mode, delete data older than 7 days
        return age > 7 * 24 * 60 * 60
    }
    
    // MARK: - Memory Privacy
    
    /// Check if memory should be encrypted
    func shouldEncryptMemory(type: MemoryType, importance: Int) -> Bool {
        guard encryptSensitiveMemories else { return false }
        // Encrypt profile info and high-importance memories in secure mode
        return type == .profile || importance >= 8
    }
}

