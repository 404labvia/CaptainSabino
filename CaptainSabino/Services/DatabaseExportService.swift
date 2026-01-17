//
//  DatabaseExportService.swift
//  YachtExpense
//
//  Servizio per export/import database (backup e trasferimento dati)
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Exported Data Structures

/// Struttura per esportare una spesa
struct ExportedExpense: Codable {
    let id: String
    let amount: Double
    let categoryName: String?
    let date: Date
    let notes: String
    let merchantName: String
    let entryType: String
    let createdAt: Date
}

/// Struttura per esportare una categoria custom
struct ExportedCategory: Codable {
    let id: String
    let name: String
    let icon: String
    let colorHex: String
    let isPredefined: Bool
}

/// Struttura completa del database esportato
struct ExportedDatabase: Codable {
    let version: Int
    let exportDate: Date
    let yachtName: String
    let captainName: String
    let expenses: [ExportedExpense]
    let customCategories: [ExportedCategory]

    static let currentVersion = 1
}

// MARK: - Database Export Service

final class DatabaseExportService {
    static let shared = DatabaseExportService()

    private init() {}

    // MARK: - Export

    /// Esporta il database completo in formato JSON
    /// - Parameters:
    ///   - expenses: Array di tutte le spese
    ///   - categories: Array di tutte le categorie
    ///   - yachtName: Nome dello yacht
    ///   - captainName: Nome del capitano
    /// - Returns: URL del file JSON temporaneo
    func exportDatabase(
        expenses: [Expense],
        categories: [Category],
        yachtName: String,
        captainName: String
    ) throws -> URL {
        // Converti spese
        let exportedExpenses = expenses.map { expense in
            ExportedExpense(
                id: expense.id.uuidString,
                amount: expense.amount,
                categoryName: expense.category?.name,
                date: expense.date,
                notes: expense.notes,
                merchantName: expense.merchantName,
                entryType: expense.entryTypeRaw,
                createdAt: expense.createdAt
            )
        }

        // Converti solo categorie custom (non predefinite)
        let customCategories = categories
            .filter { !$0.isPredefined }
            .map { category in
                ExportedCategory(
                    id: category.id.uuidString,
                    name: category.name,
                    icon: category.icon,
                    colorHex: category.colorHex,
                    isPredefined: category.isPredefined
                )
            }

        // Crea struttura export
        let exportData = ExportedDatabase(
            version: ExportedDatabase.currentVersion,
            exportDate: Date(),
            yachtName: yachtName,
            captainName: captainName,
            expenses: exportedExpenses,
            customCategories: customCategories
        )

        // Serializza in JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(exportData)

        // Salva in file temporaneo
        let fileName = generateExportFileName(yachtName: yachtName)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try jsonData.write(to: tempURL)

        return tempURL
    }

    /// Genera nome file con data e nome yacht
    private func generateExportFileName(yachtName: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        // Pulisce nome yacht per uso in filename
        let cleanYachtName = yachtName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .prefix(20)

        return "CaptainSabino_\(cleanYachtName)_\(dateString).json"
    }

    // MARK: - Import

    /// Importa il database da file JSON
    /// - Parameters:
    ///   - url: URL del file JSON
    ///   - modelContext: Context SwiftData per inserimento
    ///   - existingCategories: Categorie esistenti per matching
    /// - Returns: Risultato import con statistiche
    func importDatabase(
        from url: URL,
        modelContext: ModelContext,
        existingCategories: [Category]
    ) throws -> ImportResult {
        // Leggi file
        let jsonData = try Data(contentsOf: url)

        // Decodifica JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedData = try decoder.decode(ExportedDatabase.self, from: jsonData)

        // Verifica versione
        guard importedData.version <= ExportedDatabase.currentVersion else {
            throw ImportError.unsupportedVersion(importedData.version)
        }

        var importedExpenses = 0
        var skippedExpenses = 0
        var importedCategories = 0

        // Fetch spese esistenti per controllo duplicati
        let existingExpenseIDs = Set(existingCategories.flatMap { $0.expenses ?? [] }.map { $0.id.uuidString })

        // Crea dizionario categorie per nome (per matching)
        var categoryByName: [String: Category] = [:]
        for category in existingCategories {
            categoryByName[category.name] = category
        }

        // Importa categorie custom (se non esistono già)
        for exportedCategory in importedData.customCategories {
            if categoryByName[exportedCategory.name] == nil {
                let newCategory = Category(
                    name: exportedCategory.name,
                    icon: exportedCategory.icon,
                    color: exportedCategory.colorHex,
                    isPredefined: false
                )
                modelContext.insert(newCategory)
                categoryByName[exportedCategory.name] = newCategory
                importedCategories += 1
            }
        }

        // Importa spese (skip se ID già esistente)
        for exportedExpense in importedData.expenses {
            // Skip duplicati per ID
            if existingExpenseIDs.contains(exportedExpense.id) {
                skippedExpenses += 1
                continue
            }

            // Trova categoria corrispondente
            let category = exportedExpense.categoryName.flatMap { categoryByName[$0] }

            // Crea nuova spesa
            let newExpense = Expense(
                amount: exportedExpense.amount,
                category: category,
                date: exportedExpense.date,
                notes: exportedExpense.notes,
                merchantName: exportedExpense.merchantName,
                entryType: EntryType(rawValue: exportedExpense.entryType) ?? .manual
            )

            modelContext.insert(newExpense)
            importedExpenses += 1
        }

        // Salva
        try modelContext.save()

        return ImportResult(
            totalExpensesInFile: importedData.expenses.count,
            importedExpenses: importedExpenses,
            skippedExpenses: skippedExpenses,
            importedCategories: importedCategories,
            yachtName: importedData.yachtName,
            captainName: importedData.captainName,
            exportDate: importedData.exportDate
        )
    }
}

// MARK: - Import Result

struct ImportResult {
    let totalExpensesInFile: Int
    let importedExpenses: Int
    let skippedExpenses: Int
    let importedCategories: Int
    let yachtName: String
    let captainName: String
    let exportDate: Date

    var summary: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return """
        Import completed!

        Source: \(yachtName) - \(captainName)
        Export date: \(dateFormatter.string(from: exportDate))

        Expenses imported: \(importedExpenses)
        Expenses skipped (duplicates): \(skippedExpenses)
        Categories imported: \(importedCategories)
        """
    }
}

// MARK: - Import Error

enum ImportError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "This backup was created with a newer version (\(version)). Please update the app."
        case .invalidFormat:
            return "The file format is not valid. Please select a valid CaptainSabino backup file."
        }
    }
}

// MARK: - UTType Extension

extension UTType {
    static var captainSabinoBackup: UTType {
        UTType(exportedAs: "com.captainsabino.backup", conformingTo: .json)
    }
}
