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

/// Struttura per esportare una keyword appresa
struct ExportedKeyword: Codable {
    let categoryName: String
    let keyword: String
    let learnedDate: Date
    let usageCount: Int
    let lastUsedDate: Date
}

/// Struttura completa del database esportato
struct ExportedDatabase: Codable {
    let version: Int
    let exportDate: Date
    let yachtName: String
    let captainName: String
    let claudeAPIKey: String?
    let expenses: [ExportedExpense]
    let customCategories: [ExportedCategory]
    let learnedKeywords: [ExportedKeyword]

    static let currentVersion = 2
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
    ///   - learnedKeywords: Array delle keyword apprese
    ///   - yachtName: Nome dello yacht
    ///   - captainName: Nome del capitano
    ///   - claudeAPIKey: Claude API Key (opzionale)
    /// - Returns: URL del file JSON temporaneo
    func exportDatabase(
        expenses: [Expense],
        categories: [Category],
        learnedKeywords: [LearnedKeyword],
        yachtName: String,
        captainName: String,
        claudeAPIKey: String?
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

        // Converti keywords apprese
        let exportedKeywords = learnedKeywords.map { keyword in
            ExportedKeyword(
                categoryName: keyword.categoryName,
                keyword: keyword.keyword,
                learnedDate: keyword.learnedDate,
                usageCount: keyword.usageCount,
                lastUsedDate: keyword.lastUsedDate
            )
        }

        // Crea struttura export
        let exportData = ExportedDatabase(
            version: ExportedDatabase.currentVersion,
            exportDate: Date(),
            yachtName: yachtName,
            captainName: captainName,
            claudeAPIKey: claudeAPIKey,
            expenses: exportedExpenses,
            customCategories: customCategories,
            learnedKeywords: exportedKeywords
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
    ///   - existingExpenses: Spese esistenti per controllo duplicati
    ///   - existingCategories: Categorie esistenti per matching
    ///   - existingKeywords: Keywords esistenti per controllo duplicati
    ///   - yachtSettings: Settings esistenti per aggiornare API key
    /// - Returns: Risultato import con statistiche
    func importDatabase(
        from url: URL,
        modelContext: ModelContext,
        existingExpenses: [Expense],
        existingCategories: [Category],
        existingKeywords: [LearnedKeyword] = [],
        yachtSettings: YachtSettings? = nil
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

        var importedExpensesCount = 0
        var skippedExpenses = 0
        var importedCategories = 0
        var importedKeywords = 0

        // Funzione per creare chiave univoca per una spesa (amount + date + merchantName)
        func expenseKey(amount: Double, date: Date, merchantName: String) -> String {
            let dayTimestamp = Int(date.timeIntervalSince1970 / 86400) // Giorno senza ora
            return "\(amount)|\(dayTimestamp)|\(merchantName.lowercased().trimmingCharacters(in: .whitespaces))"
        }

        // Conta occorrenze di ogni chiave nel database esistente
        var existingExpenseCounts: [String: Int] = [:]
        for expense in existingExpenses {
            let key = expenseKey(amount: expense.amount, date: expense.date, merchantName: expense.merchantName)
            existingExpenseCounts[key, default: 0] += 1
        }

        // Conta occorrenze di ogni chiave nel file di import
        var importExpenseCounts: [String: Int] = [:]
        for exportedExpense in importedData.expenses {
            let key = expenseKey(amount: exportedExpense.amount, date: exportedExpense.date, merchantName: exportedExpense.merchantName)
            importExpenseCounts[key, default: 0] += 1
        }

        // Traccia quante spese per ogni chiave sono già state importate in questa sessione
        var importedPerKey: [String: Int] = [:]

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

        // Importa spese (skip se già presente nel DB con stesso amount+date+merchant)
        for exportedExpense in importedData.expenses {
            let key = expenseKey(amount: exportedExpense.amount, date: exportedExpense.date, merchantName: exportedExpense.merchantName)

            // Quante ne esistono già nel DB
            let existingCount = existingExpenseCounts[key] ?? 0
            // Quante ne abbiamo già importate in questa sessione
            let alreadyImported = importedPerKey[key] ?? 0
            // Totale già presenti (DB + importate questa sessione)
            let totalPresent = existingCount + alreadyImported
            // Quante ne servono dal file
            let neededFromFile = importExpenseCounts[key] ?? 0

            // Se abbiamo già abbastanza occorrenze, skip
            if totalPresent >= neededFromFile {
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
            importedExpensesCount += 1
            importedPerKey[key, default: 0] += 1
        }

        // Importa keywords apprese (se non esistono già)
        let existingKeywordPairs = Set(existingKeywords.map { "\($0.categoryName)|\($0.keyword)" })
        for exportedKeyword in importedData.learnedKeywords {
            let keyPair = "\(exportedKeyword.categoryName)|\(exportedKeyword.keyword)"
            if !existingKeywordPairs.contains(keyPair) {
                let newKeyword = LearnedKeyword(
                    categoryName: exportedKeyword.categoryName,
                    keyword: exportedKeyword.keyword,
                    learnedDate: exportedKeyword.learnedDate,
                    usageCount: exportedKeyword.usageCount,
                    lastUsedDate: exportedKeyword.lastUsedDate
                )
                modelContext.insert(newKeyword)
                importedKeywords += 1
            }
        }

        // Importa API Key (solo se presente nel backup e non già configurata)
        var apiKeyImported = false
        if let apiKey = importedData.claudeAPIKey, !apiKey.isEmpty {
            if let settings = yachtSettings {
                if settings.claudeAPIKey == nil || settings.claudeAPIKey?.isEmpty == true {
                    settings.claudeAPIKey = apiKey
                    settings.touch()
                    apiKeyImported = true
                }
            }
        }

        // Salva
        try modelContext.save()

        return ImportResult(
            totalExpensesInFile: importedData.expenses.count,
            importedExpenses: importedExpensesCount,
            skippedExpenses: skippedExpenses,
            importedCategories: importedCategories,
            importedKeywords: importedKeywords,
            apiKeyImported: apiKeyImported,
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
    let importedKeywords: Int
    let apiKeyImported: Bool
    let yachtName: String
    let captainName: String
    let exportDate: Date

    var summary: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var text = """
        Import completed!

        Source: \(yachtName) - \(captainName)
        Export date: \(dateFormatter.string(from: exportDate))

        Expenses imported: \(importedExpenses)
        Expenses skipped (duplicates): \(skippedExpenses)
        Categories imported: \(importedCategories)
        Keywords imported: \(importedKeywords)
        """

        if apiKeyImported {
            text += "\nAPI Key: imported ✓"
        }

        return text
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
