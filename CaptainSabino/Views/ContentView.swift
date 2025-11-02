//
//  ContentView.swift
//  YachtExpense
//
//  Main navigation con Tab Bar
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]
    @Query private var settings: [YachtSettings]
    @State private var showingOnboarding = false
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView()
            } else {
                TabView {
                    // Tab 1: Dashboard
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.pie")
                        }
                    
                    // Tab 2: Expenses List
                    ExpenseListView()
                        .tabItem {
                            Label("Expenses", systemImage: "list.bullet")
                        }
                    
                    // Tab 3: Reminders
                    ReminderListView()
                        .tabItem {
                            Label("Reminders", systemImage: "bell")
                        }
                    
                    // Tab 4: Settings
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
            }
        }
        .onAppear {
            initializeDataIfNeeded()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Verifica se serve l'onboarding (prima apertura)
    private var needsOnboarding: Bool {
        return settings.isEmpty || !settings[0].isComplete
    }
    
    // MARK: - Methods
    
    /// Inizializza dati di base (categorie predefinite)
    private func initializeDataIfNeeded() {
        // Crea categorie predefinite se non esistono
        if categories.isEmpty {
            let predefinedCategories = Category.createPredefinedCategories()
            for category in predefinedCategories {
                modelContext.insert(category)
            }
            
            // Crea settings vuoto
            let newSettings = YachtSettings()
            modelContext.insert(newSettings)
            
            try? modelContext.save()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, Category.self, Reminder.self, YachtSettings.self])
}
