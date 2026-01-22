//
//  NotificationService.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    func scheduleCompletionNotification(chatTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "NeoChat"
        content.body = "AI завершил генерацию ответа в чате: \(chatTitle)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleReminder(chatTitle: String, after: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Не забудьте проверить чат: \(chatTitle)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: after, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

