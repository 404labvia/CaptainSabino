//
//  LearnedKeyword.swift
//  CaptainSabino
//
//  Modello per le keyword apprese dall'OCR per associare merchant a categorie
//

import Foundation
import SwiftData

@Model
final class LearnedKeyword {
    // MARK: - Properties

    /// ID univoco
    var id: UUID

    /// Nome della categoria associata (es: "Supermarket")
    var categoryName: String

    /// Keyword estratta dal merchant (es: "conad", "carrefour")
    var keyword: String

    /// Data in cui la keyword è stata appresa
    var learnedDate: Date

    /// Numero di volte che questa associazione è stata usata
    var usageCount: Int

    /// Ultima volta che questa keyword è stata usata
    var lastUsedDate: Date

    // MARK: - Initializer

    /// Inizializzatore per creare una nuova keyword appresa
    /// - Parameters:
    ///   - categoryName: Nome della categoria da associare
    ///   - keyword: Keyword estratta dal nome merchant
    ///   - learnedDate: Data di apprendimento (default: now)
    ///   - usageCount: Contatore utilizzi (default: 1)
    ///   - lastUsedDate: Ultimo utilizzo (default: now)
    init(
        categoryName: String,
        keyword: String,
        learnedDate: Date = Date(),
        usageCount: Int = 1,
        lastUsedDate: Date = Date()
    ) {
        self.id = UUID()
        self.categoryName = categoryName
        self.keyword = keyword.lowercased() // Normalizzo in lowercase
        self.learnedDate = learnedDate
        self.usageCount = usageCount
        self.lastUsedDate = lastUsedDate
    }

    // MARK: - Computed Properties

    /// Confidenza basata sul numero di utilizzi
    var confidence: Double {
        // Più volte è stata usata, più siamo sicuri
        return min(1.0, Double(usageCount) / 5.0)
    }

    /// Descrizione formattata della keyword
    var displayText: String {
        "\(keyword) -> \(categoryName) (\(usageCount)x)"
    }
}
