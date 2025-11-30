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
    @Query private var reminders: [Reminder]
    @State private var showingOnboarding = false
    @State private var showingAddMenu = false
    @State private var showingAddExpense = false
    @State private var showingVoiceInput = false
    @State private var showingAddReminder = false
    @State private var showingCameraReceipt = false
    @State private var isProcessingReceipt = false
    @State private var processingMessage = "Processing receipt..."
    @State private var voiceParsedAmount: Double?
    @State private var voiceParsedCategory: Category?
    @State private var capturedReceiptImage: UIImage?
    @State private var selectedTab = 0

    // MARK: - Body

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView()
            } else {
                ZStack {
                    TabView(selection: $selectedTab) {
                        // Tab 0: Dashboard
                        DashboardView()
                            .tabItem {
                                Label("Dashboard", systemImage: "chart.pie")
                            }
                            .tag(0)

                        // Tab 1: Expenses List
                        ExpenseListView()
                            .tabItem {
                                Label("Expenses", systemImage: "list.bullet")
                            }
                            .tag(1)

                        // Placeholder for center button
                        Color.clear
                            .tabItem {
                                Label("", systemImage: "")
                            }
                            .tag(2)

                        // Tab 3: Reminders
                        Group {
                            if let badge = remindersBadge {
                                ReminderListView()
                                    .badge(badge)
                            } else {
                                ReminderListView()
                            }
                        }
                        .tabItem {
                            Label("Reminders", systemImage: "bell")
                        }
                        .tag(3)

                        // Tab 4: Settings
                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
                            }
                            .tag(4)
                    }

                    // Floating Add Button positioned at tab bar level
                    VStack {
                        Spacer()

                        Button {
                            handleAddButtonTap()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
                .sheet(isPresented: $showingAddExpense) {
                    AddExpenseView(
                        prefilledAmount: voiceParsedAmount,
                        prefilledCategory: voiceParsedCategory,
                        receiptImage: capturedReceiptImage
                    )
                }
                .sheet(isPresented: $showingVoiceInput) {
                    VoiceInputView { amount, category in
                        // Save parsed data
                        voiceParsedAmount = amount
                        voiceParsedCategory = category

                        // Open AddExpenseView with parsed data
                        showingAddExpense = true
                    }
                }
                .sheet(isPresented: $showingAddReminder) {
                    AddReminderView()
                }
                .sheet(isPresented: $showingCameraReceipt) {
                    CameraReceiptView { capturedImage in
                        // Start processing receipt
                        isProcessingReceipt = true
                        capturedReceiptImage = capturedImage

                        Task {
                            await processReceiptWithOCR(image: capturedImage)
                        }
                    }
                }
                .overlay {
                    if isProcessingReceipt {
                        ZStack {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()

                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)

                                Text(processingMessage)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .padding(32)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            )
                        }
                    }
                }
                .confirmationDialog("Add New Expense", isPresented: $showingAddMenu) {
                    Button("Manual Entry") {
                        // Reset voice parsed data for manual entry
                        voiceParsedAmount = nil
                        voiceParsedCategory = nil
                        capturedReceiptImage = nil
                        showingAddExpense = true
                    }

                    Button("Voice Input") {
                        showingVoiceInput = true
                    }

                    Button("📸 Scan Receipt") {
                        showingCameraReceipt = true
                    }

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Choose how to add expense")
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

    /// Conta i reminders attivi (non completati)
    private var activeRemindersCount: Int {
        reminders.filter { !$0.isCompleted }.count
    }

    /// Badge per la tab Reminders (nil se zero)
    private var remindersBadge: Int? {
        let count = activeRemindersCount
        return count > 0 ? count : nil
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

            try? modelContext.save()
        } else {
            // Update existing category colors (migration)
            updateCategoryColorsIfNeeded()
        }

        // Verifica e pulisci settings corrotti o duplicati
        cleanupSettingsIfNeeded()
    }

    /// Pulisce settings duplicati o corrotti dal database
    private func cleanupSettingsIfNeeded() {
        // Se ci sono più settings, teniamo solo il primo completo o l'ultimo
        if settings.count > 1 {
            print("⚠️ Found \(settings.count) YachtSettings, cleaning up...")

            // Trova il primo settings completo
            if let completeSettings = settings.first(where: { $0.isComplete }) {
                // Elimina tutti gli altri
                for setting in settings where setting.id != completeSettings.id {
                    modelContext.delete(setting)
                }
            } else {
                // Nessuno è completo, elimina tutti tranne l'ultimo
                for (index, setting) in settings.enumerated() {
                    if index < settings.count - 1 {
                        modelContext.delete(setting)
                    }
                }
            }

            try? modelContext.save()
        }

        // Se non ci sono settings, crea uno vuoto per l'onboarding
        if settings.isEmpty {
            print("ℹ️ Creating empty YachtSettings for onboarding")
            let newSettings = YachtSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
        }
    }

    /// Aggiorna i colori delle categorie esistenti con i nuovi colori e aggiunge nuove categorie
    private func updateCategoryColorsIfNeeded() {
        let hasUpdatedCategories = UserDefaults.standard.bool(forKey: "hasUpdatedCategories_v5")

        guard !hasUpdatedCategories else { return }

        // Mapping dei nuovi colori per categorie esistenti
        let colorMapping: [String: String] = [
            "Food": "#E53935",        // Rosso vivace
            "Fuel": "#1E88E5",        // Blu navy
            "Pharmacy": "#00897B",    // Verde smeraldo
            "Crew": "#D81B60",        // Magenta
            "Chandlery": "#FB8C00",   // Arancione
            "Water Test": "#03A9F4",  // Azzurro
            "Welder": "#FF6F00",      // Arancione scuro
            "Tender Fuel": "#607D8B", // Grigio-blu
            "Fly": "#00BCD4",         // Celeste
            "Supermarket": "#8BC34A"  // Verde lime
        ]

        // Aggiorna i colori delle categorie esistenti
        for category in categories where category.isPredefined {
            if let newColor = colorMapping[category.name] {
                category.colorHex = newColor
            }
        }

        // Rimuovi categorie vecchie (Supplies, Maintenance, Mooring)
        let categoriesToRemove = ["Supplies", "Maintenance", "Mooring"]
        for category in categories where category.isPredefined {
            if categoriesToRemove.contains(category.name) {
                // Se la categoria ha spese, non la cancelliamo ma la rendiamo custom
                if let expenses = category.expenses, !expenses.isEmpty {
                    category.isPredefined = false
                } else {
                    // Nessuna spesa, possiamo cancellare
                    modelContext.delete(category)
                }
            }
        }

        // Aggiungi nuove categorie se non esistono
        let existingCategoryNames = Set(categories.map { $0.name })
        let newCategories: [(name: String, icon: String, color: String)] = [
            ("Chandlery", "wrench.and.screwdriver", "#FB8C00"),
            ("Water Test", "drop.triangle", "#03A9F4"),
            ("Welder", "flame", "#FF6F00"),
            ("Tender Fuel", "fuelpump.fill", "#607D8B"),
            ("Fly", "airplane", "#00BCD4"),
            ("Supermarket", "bag", "#8BC34A")
        ]

        for newCat in newCategories {
            if !existingCategoryNames.contains(newCat.name) {
                let category = Category(name: newCat.name, icon: newCat.icon, color: newCat.color)
                modelContext.insert(category)
            }
        }

        try? modelContext.save()

        // Salva il flag per non ripetere l'aggiornamento
        UserDefaults.standard.set(true, forKey: "hasUpdatedCategories_v5")
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

    /// Gestisce il tap sul pulsante + in base alla tab selezionata
    private func handleAddButtonTap() {
        if selectedTab == 3 {
            // Tab Reminders: apre direttamente Add Reminder
            showingAddReminder = true
        } else {
            // Altre tab: mostra il menu per aggiungere expense
            showingAddMenu = true
        }
    }

    /// Processa lo scontrino con OCR (con auto-retry Claude se fallisce)
    private func processReceiptWithOCR(image: UIImage) async {
        // Step 1: Reset message
        await MainActor.run {
            processingMessage = "Processing receipt..."
        }

        // Step 2: Try Apple Vision OCR first (without Claude)
        var receiptData = await ReceiptOCRService.shared.processReceipt(
            image: image,
            claudeAPIKey: nil  // Don't use Claude yet
        )

        // Step 3: If amount not found AND Claude API key exists, retry with Claude
        print("🔍 DEBUG - Amount: \(receiptData.amount?.description ?? "nil")")
        print("🔍 DEBUG - Settings count: \(settings.count)")
        print("🔍 DEBUG - API Key exists: \(settings.first?.claudeAPIKey != nil)")
        print("🔍 DEBUG - API Key length: \(settings.first?.claudeAPIKey?.count ?? 0)")

        if receiptData.amount == nil,
           let claudeAPIKey = settings.first?.claudeAPIKey,
           !claudeAPIKey.isEmpty {

            print("⚠️ Amount not found, retrying with Claude API...")
            print("🔑 Claude API key found: \(String(claudeAPIKey.prefix(15)))... (length: \(claudeAPIKey.count))")

            // Update message to show AI retry
            await MainActor.run {
                processingMessage = "🤖 Retrying with AI..."
            }

            // Retry with Claude API
            receiptData = await ReceiptOCRService.shared.processReceipt(
                image: image,
                claudeAPIKey: claudeAPIKey
            )

            if receiptData.amount != nil {
                print("✅ Amount found with Claude API: €\(receiptData.amount!)")
            } else {
                print("❌ Amount still not found even with Claude")
            }
        } else {
            // Debug: why Claude API was not called
            if receiptData.amount != nil {
                print("ℹ️ Claude API not needed (amount found by Apple Vision)")
            } else if settings.first?.claudeAPIKey == nil {
                print("❌ Claude API key is NIL in settings!")
            } else if settings.first?.claudeAPIKey?.isEmpty == true {
                print("❌ Claude API key is EMPTY string!")
            } else {
                print("❌ Unknown reason for not calling Claude")
            }
        }

        // Find category in database by name
        var matchedCategory: Category?
        if let categoryName = receiptData.categoryName {
            matchedCategory = categories.first { $0.name == categoryName }
        }

        // Prepare data for AddExpenseView
        await MainActor.run {
            voiceParsedAmount = receiptData.amount
            voiceParsedCategory = matchedCategory

            // Hide processing overlay
            isProcessingReceipt = false

            // Open AddExpenseView with parsed data
            showingAddExpense = true
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, Category.self, Reminder.self, YachtSettings.self])
}
