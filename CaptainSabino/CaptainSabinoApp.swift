//
//  CaptainSabinoApp.swift
//  CaptainSabino
//
//  Entry point dell'applicazione con CloudKit sync
//

import SwiftUI
import SwiftData

@main
struct CaptainSabinoApp: App {
    // Container condiviso per tutta l'app
    let sharedModelContainer: ModelContainer

    init() {
        // Schema con tutti i modelli
        let schema = Schema([
            Expense.self,
            Category.self,
            Reminder.self,
            YachtSettings.self,
            LearnedKeyword.self
        ])

        // Configurazione con CloudKit
        // Container: iCloud.it.404lab.CaptainSabino
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            sharedModelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ ModelContainer inizializzato con CloudKit")
        } catch {
            // Fallback senza CloudKit in caso di errore
            print("⚠️ Errore CloudKit, fallback a storage locale: \(error)")
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                sharedModelContainer = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfig]
                )
            } catch {
                fatalError("❌ Impossibile creare ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
