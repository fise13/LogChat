//
//  LogChatApp.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import CoreData

@main
struct LogChatApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
