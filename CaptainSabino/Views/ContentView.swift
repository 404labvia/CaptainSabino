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
    @State private var showingAddMenu = false
    @State private var showingAddExpense = false
    @State private var showingAddReminder = false

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

                    // Tab 3: Add Button (elevated)
                    Color.clear
                        .onTapGesture {
                            showingAddMenu.toggle()
                        }
                        .tabItem {
                            Label("", systemImage: "plus.circle.fill")
                                .environment(\.symbolVariants, .none)
                        }

                    // Tab 4: Reminders
                    ReminderListView()
                        .tabItem {
                            Label("Reminders", systemImage: "bell")
                        }

                    // Tab 5: Settings
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
                .onAppear {
                    // Customize tab bar appearance for elevated center button effect
                    let appearance = UITabBarAppearance()
                    appearance.configureWithDefaultBackground()
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
                .sheet(isPresented: $showingAddExpense) {
                    AddExpenseView()
                }
                .sheet(isPresented: $showingAddReminder) {
                    AddReminderView()
                }
                .confirmationDialog("Add New", isPresented: $showingAddMenu) {
                    Button("Add Expense") {
                        showingAddExpense = true
                    }

                    Button("Add Reminder") {
                        showingAddReminder = true
                    }

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("What would you like to add?")
                }
            }
        }
        .onAppear {
            initializeDataIfNeeded()
            requestNotificationPermissions()
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
        } else {
            // Update existing category colors (migration)
            updateCategoryColorsIfNeeded()
        }
    }

    /// Aggiorna i colori delle categorie esistenti con i nuovi colori
    private func updateCategoryColorsIfNeeded() {
        let hasUpdatedColors = UserDefaults.standard.bool(forKey: "hasUpdatedCategoryColors_v2")

        guard !hasUpdatedColors else { return }

        // Mapping dei nuovi colori
        let colorMapping: [String: String] = [
            "Food": "#E53935",        // Rosso vivace
            "Fuel": "#1E88E5",        // Blu navy
            "Pharmacy": "#00897B",    // Verde smeraldo
            "Maintenance": "#FB8C00", // Arancione
            "Mooring": "#5E35B1",     // Viola
            "Crew": "#D81B60",        // Magenta
            "Supplies": "#6D4C41"     // Marrone
        ]

        // Aggiorna i colori delle categorie esistenti
        for category in categories where category.isPredefined {
            if let newColor = colorMapping[category.name] {
                category.colorHex = newColor
            }
        }

        try? modelContext.save()

        // Salva il flag per non ripetere l'aggiornamento
        UserDefaults.standard.set(true, forKey: "hasUpdatedCategoryColors_v2")
    }

    /// Richiede i permessi per le notifiche all'avvio dell'app
    private func requestNotificationPermissions() {
        NotificationService.shared.requestAuthorization { granted in
            if granted {
                print("✅ Notification permissions granted")
            } else {
                print("⚠️ Notification permissions denied")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, Category.self, Reminder.self, YachtSettings.self])
}
