//
//  LogChatApp.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct LogChatApp: App {
    #if canImport(FirebaseCore)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif
    
    init() {
        #if canImport(FirebaseCore)
        // Firebase будет инициализирован в AppDelegate
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Chat.self, ChatMessage.self, CustomMode.self, QueryTemplate.self, FavoriteResponse.self, UsageStatistics.self, Note.self, FocusSession.self, MemoryItem.self, Workspace.self, Project.self, ProjectTask.self, ProjectReport.self])
    }
}

#if canImport(FirebaseCore)
#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
#endif
#endif
