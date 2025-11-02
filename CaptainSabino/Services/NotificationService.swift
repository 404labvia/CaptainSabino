//
//  NotificationService.swift
//  YachtExpense
//
//  Servizio per gestione notifiche locali
//

import Foundation
import UserNotifications

class NotificationService {
    // MARK: - Singleton
    
    static let shared = NotificationService()
    private init() {}
    
    // MARK: - Notification Permission
    
    /// Richiede il permesso per le notifiche
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
            completion(granted)
        }
    }
    
    /// Verifica se le notifiche sono autorizzate
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus == .authorized)
        }
    }
    
    // MARK: - Schedule Notifications
    
    /// Schedula una notifica per un promemoria
    /// - Parameter reminder: Il promemoria da schedulare
    func scheduleReminder(_ reminder: Reminder) {
        // Verifica che la data sia futura
        guard reminder.dueDate > Date() else {
            print("⚠️ Cannot schedule reminder in the past")
            return
        }
        
        // Crea il contenuto della notifica
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(reminder.title)"
        content.body = reminder.notes.isEmpty ? "You have a reminder due" : reminder.notes
        content.sound = .default
        content.badge = 1
        
        // Crea il trigger basato sulla data
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Crea la richiesta
        let notificationId = reminder.id.uuidString
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        
        // Schedula la notifica
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification scheduled: \(reminder.title)")
                // Salva l'ID della notifica nel reminder
                reminder.notificationId = notificationId
            }
        }
    }
    
    /// Cancella una notifica specifica
    /// - Parameter identifier: L'ID della notifica da cancellare
    func cancelNotification(_ identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Notification cancelled: \(identifier)")
    }
    
    /// Cancella tutte le notifiche pendenti
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All notifications cancelled")
    }
    
    /// Ottiene il numero di notifiche pendenti
    func getPendingNotificationsCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests.count)
        }
    }
}
