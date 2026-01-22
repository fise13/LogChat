//
//  NetworkMonitor.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import Network
import Combine

/// Monitors network connectivity
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .wifi
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unavailable
    }
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                self.isConnected = path.status == .satisfied
                self.connectionType = self.determineConnectionType(path)
                
                // Post notification
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": self.isConnected]
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unavailable
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
