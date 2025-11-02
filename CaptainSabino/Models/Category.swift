//
//  Category.swift
//  YachtExpense
//
//  Modello per le categorie di spesa
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    // MARK: - Properties
    
    /// ID univoco della categoria
    var id: UUID
    
    /// Nome della categoria (es: "Food", "Fuel")
    var name: String
    
    /// Icona SF Symbol per la categoria (es: "fork.knife")
    var icon: String
    
    /// Colore in formato HEX (es: "#FF6B6B")
    var colorHex: String
    
    /// Indica se è una categoria predefinita o custom
    var isPredefined: Bool
    
    /// Data di creazione
    var createdAt: Date
    
    /// Relazione inversa con le spese
    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]?
    
    // MARK: - Initializer
    
    /// Inizializzatore per creare una nuova categoria
    /// - Parameters:
    ///   - name: Nome della categoria
    ///   - icon: Nome dell'icona SF Symbol
    ///   - color: Colore in HEX
    ///   - isPredefined: Se è predefinita o custom (default: true)
    init(
        name: String,
        icon: String,
        color: String,
        isPredefined: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = color
        self.isPredefined = isPredefined
        self.createdAt = Date()
        self.expenses = []
    }
    
    // MARK: - Computed Properties
    
    /// Converte il colore HEX in SwiftUI Color
    var color: Color {
        return Color(hex: colorHex)
    }
    
    /// Ritorna il numero di spese associate
    var expenseCount: Int {
        return expenses?.count ?? 0
    }
}

// MARK: - Categorie Predefinite

extension Category {
    /// Crea tutte le categorie predefinite
    static func createPredefinedCategories() -> [Category] {
        return [
            Category(
                name: "Food",
                icon: "fork.knife",
                color: "#FF6B6B"
            ),
            Category(
                name: "Fuel",
                icon: "fuelpump",
                color: "#4ECDC4"
            ),
            Category(
                name: "Pharmacy",
                icon: "cross.case",
                color: "#95E1D3"
            ),
            Category(
                name: "Maintenance",
                icon: "wrench.and.screwdriver",
                color: "#F38181"
            ),
            Category(
                name: "Mooring",
                icon: "anchor",
                color: "#AA96DA"
            ),
            Category(
                name: "Crew",
                icon: "person.3",
                color: "#FCBAD3"
            ),
            Category(
                name: "Supplies",
                icon: "shippingbox",
                color: "#FFFFD2"
            )
        ]
    }
    
    /// Dati di esempio per Preview
    static var sampleCategories: [Category] {
        return createPredefinedCategories()
    }
}

// MARK: - Color Extension (Supporto HEX)

extension Color {
    /// Inizializzatore per creare Color da stringa HEX
    /// - Parameter hex: Stringa HEX (es: "#FF6B6B" o "FF6B6B")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        default:
            (r, g, b) = (255, 255, 255) // Fallback a bianco
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
