//
//  Reminder.swift
//  YachtExpense
//
//  Modello per i promemoria di scadenze
//

import Foundation
import SwiftData

@Model
final class Reminder {
    // MARK: - Properties
    
    /// ID univoco del promemoria
    var id: UUID
    
    /// Titolo del promemoria (es: "Insurance Renewal")
    var title: String
    
    /// Descrizione/note opzionali
    var notes: String
    
    /// Data e ora della scadenza
    var dueDate: Date
    
    /// Indica se il promemoria è stato completato
    var isCompleted: Bool
    
    /// ID della notifica locale iOS (per cancellare/modificare)
    var notificationId: String?
    
    /// Data di creazione
    var createdAt: Date
    
    // MARK: - Initializer
    
    /// Inizializzatore per creare un nuovo promemoria
    /// - Parameters:
    ///   - title: Titolo del promemoria
    ///   - notes: Note opzionali
    ///   - dueDate: Data di scadenza
    ///   - isCompleted: Se completato (default: false)
    init(
        title: String,
        notes: String = "",
        dueDate: Date,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Ritorna la data formattata
    var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
    
    /// Verifica se il promemoria è scaduto
    var isOverdue: Bool {
        return !isCompleted && dueDate < Date()
    }
    
    /// Giorni rimanenti (negativo se scaduto)
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: dueDate)
        return components.day ?? 0
    }
    
    /// Testo descrittivo dello stato
    var statusText: String {
        if isCompleted {
            return "Completed"
        } else if isOverdue {
            return "Overdue"
        } else if daysRemaining == 0 {
            return "Due today"
        } else if daysRemaining == 1 {
            return "Due tomorrow"
        } else {
            return "Due in \(daysRemaining) days"
        }
    }
}

// MARK: - Extension per Sample Data

extension Reminder {
    /// Dati di esempio per Preview
    static var sampleReminders: [Reminder] {
        let calendar = Calendar.current
        
        return [
            Reminder(
                title: "Insurance Renewal",
                notes: "Annual yacht insurance renewal",
                dueDate: calendar.date(byAdding: .day, value: 15, to: Date())!,
                isCompleted: false
            ),
            Reminder(
                title: "Engine Maintenance",
                notes: "Scheduled maintenance check",
                dueDate: calendar.date(byAdding: .day, value: 30, to: Date())!,
                isCompleted: false
            ),
            Reminder(
                title: "Safety Equipment Check",
                notes: "Verify all safety equipment is up to date",
                dueDate: calendar.date(byAdding: .day, value: -5, to: Date())!,
                isCompleted: false
            ),
            Reminder(
                title: "License Renewal",
                notes: "Captain's license renewal",
                dueDate: calendar.date(byAdding: .month, value: 2, to: Date())!,
                isCompleted: false
            )
        ]
    }
}
