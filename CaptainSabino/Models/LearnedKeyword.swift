//
//  LearnedKeyword.swift
//  CaptainSabino
//
//  Modello per salvare le keyword apprese per categorizzazione automatica
//

import Foundation
import SwiftData

@Model
final class LearnedKeyword {
    // MARK: - Properties

    var id: UUID
    var keyword: String
    var categoryName: String
    var usageCount: Int
    var createdAt: Date
    var lastUsedAt: Date

    // MARK: - Initialization

    init(keyword: String, categoryName: String) {
        self.id = UUID()
        self.keyword = keyword.uppercased()
        self.categoryName = categoryName
        self.usageCount = 1
        self.createdAt = Date()
        self.lastUsedAt = Date()
    }

    // MARK: - Methods

    /// Incrementa il contatore di utilizzo
    func incrementUsage() {
        usageCount += 1
        lastUsedAt = Date()
    }
}
