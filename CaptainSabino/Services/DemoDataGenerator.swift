//
//  DemoDataGenerator.swift
//  CaptainSabino
//
//  Genera spese demo SOLO per Simulator (screenshot e video)
//  NON viene eseguito su device fisico
//

import Foundation
import SwiftData

#if targetEnvironment(simulator)

final class DemoDataGenerator {
    static let shared = DemoDataGenerator()

    private init() {}

    /// Genera 40 spese demo per i mesi Settembre-Dicembre 2025
    /// Chiamare SOLO da Simulator per screenshot/video
    func generateDemoExpenses(modelContext: ModelContext, categories: [Category]) {
        // Verifica che siamo su Simulator
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil else {
            print("⚠️ DemoDataGenerator: Non su Simulator, skip")
            return
        }

        print("🎬 Generazione spese demo per screenshot...")

        let calendar = Calendar.current

        // Dati demo realistici per yacht
        let demoExpenses: [(amount: Double, category: String, merchant: String, notes: String, entryType: EntryType, month: Int, day: Int)] = [
            // DICEMBRE 2025 (10 spese)
            (1250.00, "Fuel", "Marina di Portofino", "Diesel refuel", .receipt, 12, 28),
            (89.50, "Food", "Ristorante Il Pescatore", "Crew lunch", .receipt, 12, 27),
            (450.00, "Chandlery", "Yacht Parts Monaco", "Spare filters", .invoice, 12, 24),
            (35.00, "Parking", "Porto di Sanremo", "Van parking", .manual, 12, 22),
            (156.80, "Supermarket", "Carrefour Market", "Provisions", .receipt, 12, 20),
            (78.00, "Laundry", "Lavanderia Nautica", "Crew uniforms", .receipt, 12, 18),
            (320.00, "Tender Fuel", "Esso Marina", "Tender refuel", .receipt, 12, 15),
            (1890.00, "Fly", "Air France", "Crew flights", .invoice, 12, 12),
            (45.00, "Pharmacy", "Farmacia del Porto", "First aid supplies", .receipt, 12, 10),
            (67.50, "Food", "Bar Nautico", "Coffee and snacks", .manual, 12, 5),

            // NOVEMBRE 2025 (10 spese)
            (2100.00, "Fuel", "Total Energies Marina", "Full tank diesel", .invoice, 11, 28),
            (234.00, "Food", "Trattoria del Mare", "Guest dinner", .receipt, 11, 25),
            (890.00, "Chandlery", "Accastillage Diffusion", "Navigation equipment", .invoice, 11, 22),
            (55.00, "Parking", "Parking Port Vauban", "Crew car", .manual, 11, 20),
            (178.90, "Supermarket", "Super U Marine", "Weekly provisions", .receipt, 11, 18),
            (95.00, "Laundry", "Pressing Nautique", "Table linens", .receipt, 11, 15),
            (180.00, "Tender Fuel", "Shell Marina", "Tender + jetski", .receipt, 11, 12),
            (45.50, "Pharmacy", "Pharmacie du Port", "Seasickness medicine", .receipt, 11, 8),
            (2450.00, "Fly", "British Airways", "Owner pickup", .invoice, 11, 5),
            (123.00, "Food", "Cafe de la Marine", "Crew breakfast week", .manual, 11, 2),

            // OTTOBRE 2025 (10 spese)
            (1680.00, "Fuel", "BP Marine Antibes", "Diesel 800L", .receipt, 10, 30),
            (567.00, "Chandlery", "Ship Shop Monaco", "Cleaning supplies", .invoice, 10, 27),
            (89.00, "Food", "Pizzeria Napoli", "Crew dinner", .receipt, 10, 24),
            (42.00, "Parking", "Parking Croisette", "Daily parking", .manual, 10, 22),
            (245.60, "Supermarket", "Monoprix", "Provisions + drinks", .receipt, 10, 20),
            (78.00, "Laundry", "Blanchisserie Marine", "Bedding", .receipt, 10, 17),
            (95.00, "Tender Fuel", "Eni Station", "Tender fuel", .receipt, 10, 14),
            (1230.00, "Fly", "EasyJet", "Crew rotation flights", .invoice, 10, 10),
            (34.80, "Pharmacy", "Farmacia Centrale", "Sunscreen supplies", .receipt, 10, 7),
            (156.00, "Food", "Le Petit Nice", "Captain lunch meeting", .receipt, 10, 3),

            // SETTEMBRE 2025 (10 spese)
            (2340.00, "Fuel", "Marina Porto Cervo", "Full refuel", .invoice, 9, 28),
            (345.00, "Food", "Ristorante Clipper", "Guest lunch", .receipt, 9, 25),
            (1200.00, "Chandlery", "Rigging Service", "Rope replacement", .invoice, 9, 22),
            (28.00, "Parking", "Porto Rotondo Parking", "Half day", .manual, 9, 20),
            (312.40, "Supermarket", "Conad", "Major provisioning", .receipt, 9, 18),
            (120.00, "Laundry", "Lavanderia Express", "Full service", .receipt, 9, 15),
            (210.00, "Tender Fuel", "Q8 Marina", "Tender full tank", .receipt, 9, 12),
            (67.00, "Pharmacy", "Farmacia Olbia", "Medical kit refill", .receipt, 9, 8),
            (3200.00, "Fly", "Lufthansa", "Owner + guests flights", .invoice, 9, 5),
            (89.00, "Food", "Bar Sport", "Crew refreshments", .manual, 9, 2),
        ]

        // Crea dizionario categorie per nome
        var categoryByName: [String: Category] = [:]
        for category in categories {
            categoryByName[category.name] = category
        }

        var created = 0

        for expense in demoExpenses {
            // Crea data
            var components = DateComponents()
            components.year = 2025
            components.month = expense.month
            components.day = expense.day
            components.hour = Int.random(in: 9...18)
            components.minute = Int.random(in: 0...59)

            guard let date = calendar.date(from: components) else { continue }
            guard let category = categoryByName[expense.category] else {
                print("⚠️ Categoria non trovata: \(expense.category)")
                continue
            }

            let newExpense = Expense(
                amount: expense.amount,
                category: category,
                date: date,
                notes: expense.notes,
                merchantName: expense.merchant,
                entryType: expense.entryType
            )

            modelContext.insert(newExpense)
            created += 1
        }

        do {
            try modelContext.save()
            print("✅ Create \(created) spese demo!")
        } catch {
            print("❌ Errore salvataggio spese demo: \(error)")
        }
    }

    /// Rimuove tutte le spese demo (per pulire dopo screenshot)
    func clearAllExpenses(modelContext: ModelContext, expenses: [Expense]) {
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil else {
            print("⚠️ DemoDataGenerator: Non su Simulator, skip")
            return
        }

        print("🗑️ Rimozione spese demo...")

        for expense in expenses {
            modelContext.delete(expense)
        }

        do {
            try modelContext.save()
            print("✅ Spese rimosse!")
        } catch {
            print("❌ Errore rimozione: \(error)")
        }
    }
}

#else

// Versione vuota per device fisico - non fa nulla
final class DemoDataGenerator {
    static let shared = DemoDataGenerator()
    private init() {}

    func generateDemoExpenses(modelContext: ModelContext, categories: [Category]) {
        // Non fare nulla su device fisico
    }

    func clearAllExpenses(modelContext: ModelContext, expenses: [Expense]) {
        // Non fare nulla su device fisico
    }
}

#endif
