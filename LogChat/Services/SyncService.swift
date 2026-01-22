//
//  SyncService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import SwiftData
import Combine

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case error(String)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.success, .success):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startAutoSync()
    }
    
    // MARK: - Public API
    
    /// Запускает синхронизацию всех данных
    func syncAll(context: ModelContext) async {
        guard syncStatus != .syncing else { return }
        
        syncStatus = .syncing
        
        do {
            // Используем Firebase для синхронизации (централизованно)
            await FirebaseService.shared.syncAll(context: context)
            
            syncStatus = .success
            lastSyncDate = Date()
            
            // Сохраняем дату последней синхронизации
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            print("❌ Sync error: \(error)")
        }
    }
    
    /// Загружает данные из облака
    func pullFromCloud(context: ModelContext) async throws {
        // В реальной реализации здесь будет загрузка из облака
        // Пока используем локальное хранилище как источник истины
        print("📥 Pulling data from cloud...")
    }
    
    /// Отправляет данные в облако
    func pushToCloud(context: ModelContext) async throws {
        // Данные отправляются через FirebaseService
        print("📤 Pushing data to Firebase...")
    }
    
    // MARK: - Private Implementation
    
    private func syncChats(context: ModelContext) async throws {
        // Синхронизация делегирована FirebaseService
        // Удалено дублирование логики
    }
    
    private func syncNotes(context: ModelContext) async throws {
        // Синхронизация делегирована FirebaseService
        // Удалено дублирование логики
    }
    
    private func startAutoSync() {
        // Автосинхронизация отключена для оптимизации
        // Используется только ручная синхронизация через FirebaseService
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}

