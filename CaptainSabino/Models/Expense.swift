//
//  Expense.swift
//  YachtExpense
//
//  Modello per rappresentare una singola spesa
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Entry Type Enum

/// Tipo di inserimento della spesa
enum EntryType: String, Codable {
    case manual = "C"    // Cash/Manual entry
    case receipt = "R"   // Receipt scan
    case invoice = "I"   // Invoice upload

    /// Colore associato al tipo di inserimento
    var color: Color {
        switch self {
        case .manual: return .orange
        case .receipt: return .green
        case .invoice: return .purple
        }
    }

    /// Lettera da visualizzare nel badge
    var displayLetter: String { rawValue }

    /// Descrizione completa per la legenda
    var description: String {
        switch self {
        case .manual: return "Cash (Manual)"
        case .receipt: return "Receipt"
        case .invoice: return "Invoice"
        }
    }
}

@Model
final class Expense {
    // MARK: - Properties

    /// ID univoco della spesa (generato automaticamente)
    var id: UUID = UUID()

    /// Importo della spesa in Euro
    var amount: Double = 0.0

    /// Categoria della spesa (relazione con Category)
    var category: Category?

    /// Data della spesa
    var date: Date = Date()

    /// Note opzionali per la spesa (es: "Rifornimento Porto di Monaco")
    var notes: String = ""

    /// Percorso relativo dell'immagine dello scontrino (se presente)
    var receiptImagePath: String?

    /// Nome del commerciante/fornitore (es: "Esselunga", "ENI Station")
    var merchantName: String = ""

    /// Tipo di inserimento della spesa (Manual, Receipt, Invoice)
    /// Default "R" per retrocompatibilità con dati esistenti (erano da scontrino)
    var entryTypeRaw: String = "R"

    /// Entry type come enum (computed property per SwiftData compatibility)
    var entryType: EntryType {
        get { EntryType(rawValue: entryTypeRaw) ?? .manual }
        set { entryTypeRaw = newValue.rawValue }
    }

    /// Data di creazione del record
    var createdAt: Date = Date()
    
    // MARK: - Initializer

    /// Inizializzatore per creare una nuova spesa
    /// - Parameters:
    ///   - amount: Importo in Euro
    ///   - category: Categoria della spesa
    ///   - date: Data della spesa (default: oggi)
    ///   - notes: Note opzionali (default: stringa vuota)
    ///   - receiptImagePath: Percorso immagine scontrino (default: nil)
    ///   - merchantName: Nome commerciante (default: stringa vuota)
    ///   - entryType: Tipo di inserimento (default: manual)
    init(
        amount: Double,
        category: Category?,
        date: Date = Date(),
        notes: String = "",
        receiptImagePath: String? = nil,
        merchantName: String = "",
        entryType: EntryType = .manual
    ) {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.date = date
        self.notes = notes
        self.receiptImagePath = receiptImagePath
        self.merchantName = merchantName
        self.entryTypeRaw = entryType.rawValue
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
    
    /// Ritorna l'importo formattato con simbolo Euro (formato italiano)
    var formattedAmount: String {
        return amount.formattedCurrency
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
                notes: "Weekly groceries",
                merchantName: "Esselunga"
            ),
            Expense(
                amount: 850.00,
                category: fuelCategory,
                date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                notes: "Fuel refill - Monaco Port",
                merchantName: "ENI Station"
            ),
            Expense(
                amount: 45.00,
                category: foodCategory,
                date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
                notes: "Restaurant supplies",
                merchantName: "Ristorante Da Mario"
            )
        ]
    }
}

// MARK: - Extension per formattazione valuta italiana

extension Double {
    /// Formatta il valore come valuta italiana: € 2.460,50
    /// (migliaia con punto, decimali con virgola)
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "€ "
        formatter.currencyDecimalSeparator = ","
        formatter.currencyGroupingSeparator = "."
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "€ 0,00"
    }
}
