//
//  Expense.swift
//  YachtExpense
//
//  Modello per rappresentare una singola spesa
//

import Foundation
import SwiftData

@Model
final class Expense {
    // MARK: - Properties
    
    /// ID univoco della spesa (generato automaticamente)
    var id: UUID
    
    /// Importo della spesa in Euro
    var amount: Double
    
    /// Categoria della spesa (relazione con Category)
    var category: Category?
    
    /// Data della spesa
    var date: Date
    
    /// Note opzionali per la spesa (es: "Rifornimento Porto di Monaco")
    var notes: String
    
    /// Data di creazione del record
    var createdAt: Date
    
    // MARK: - Initializer
    
    /// Inizializzatore per creare una nuova spesa
    /// - Parameters:
    ///   - amount: Importo in Euro
    ///   - category: Categoria della spesa
    ///   - date: Data della spesa (default: oggi)
    ///   - notes: Note opzionali (default: stringa vuota)
    init(
        amount: Double,
        category: Category?,
        date: Date = Date(),
        notes: String = ""
    ) {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Ritorna il mese e anno della spesa (per filtraggio)
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    /// Ritorna la data formattata per la UI
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Ritorna l'importo formattato con simbolo Euro
    var formattedAmount: String {
        return String(format: "€%.2f", amount)
    }

    /// Ritorna la chiave per raggruppamento per giorno (data senza ora)
    var dayKey: Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Ritorna il testo per l'header del giorno (Today, Yesterday, o data completa)
    var dayHeaderText: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expenseDay = calendar.startOfDay(for: date)

        if expenseDay == today {
            return "Today"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  expenseDay == yesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// MARK: - Extension per Sample Data (Preview)

extension Expense {
    /// Dati di esempio per SwiftUI Previews
    static var sampleExpenses: [Expense] {
        let foodCategory = Category(name: "Food", icon: "fork.knife", color: "#FF6B6B")
        let fuelCategory = Category(name: "Fuel", icon: "fuelpump", color: "#4ECDC4")
        
        return [
            Expense(
                amount: 250.50,
                category: foodCategory,
                date: Date(),
                notes: "Weekly groceries"
            ),
            Expense(
                amount: 850.00,
                category: fuelCategory,
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                notes: "Fuel refill - Monaco Port"
            ),
            Expense(
                amount: 45.00,
                category: foodCategory,
                date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
                notes: "Restaurant supplies"
            )
        ]
    }
}
