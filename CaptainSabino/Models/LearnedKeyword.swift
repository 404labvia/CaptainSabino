//
//  LearnedKeyword.swift
//  CaptainSabino
//
//  Modello per keyword apprese dall'utente per categorizzazione automatica
//

import Foundation
import SwiftData

@Model
final class LearnedKeyword {
    // MARK: - Properties

    /// ID univoco
    var id: UUID

    /// Nome della categoria associata
    var categoryName: String

    /// Keyword estratta dal merchant
    var keyword: String

    /// Data in cui è stata appresa
    var learnedDate: Date

    /// Numero di volte che è stata usata
    var usageCount: Int

    /// Ultima data di utilizzo
    var lastUsedDate: Date

    // MARK: - Initializer

    init(
        categoryName: String,
        keyword: String,
        learnedDate: Date = Date(),
        usageCount: Int = 1,
        lastUsedDate: Date = Date()
    ) {
        self.id = UUID()
        self.categoryName = categoryName
        self.keyword = keyword
        self.learnedDate = learnedDate
        self.usageCount = usageCount
        self.lastUsedDate = lastUsedDate
    }
}
