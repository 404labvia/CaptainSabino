//
//  LearnedKeyword.swift
//  CaptainSabino
//
//  Modello per keyword apprese automaticamente dal sistema
//  Migliora accuracy categorizzazione nel tempo
//

import Foundation
import SwiftData

@Model
class LearnedKeyword {
    /// Nome della categoria associata (es. "Supermarket", "Food")
    var categoryName: String

    /// Keyword appresa (es. "TIRRENICA", "PORTOFINO")
    var keyword: String

    /// Data in cui è stata appresa
    var learnedDate: Date

    /// Contatore di quante volte è stata trovata e confermata
    var usageCount: Int

    /// Data dell'ultimo utilizzo (per cleanup automatico)
    var lastUsedDate: Date

    init(
        categoryName: String,
        keyword: String,
        learnedDate: Date = Date(),
        usageCount: Int = 1,
        lastUsedDate: Date = Date()
    ) {
        self.categoryName = categoryName
        self.keyword = keyword
        self.learnedDate = learnedDate
        self.usageCount = usageCount
        self.lastUsedDate = lastUsedDate
    }
}
