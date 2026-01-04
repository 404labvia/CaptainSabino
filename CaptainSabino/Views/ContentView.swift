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
    @Query private var learnedKeywords: [LearnedKeyword]
    @State private var showingOnboarding = false
    @State private var showingAddMenu = false
    @State private var showingAddExpense = false
    @State private var showingCameraReceipt = false
    @State private var isProcessingReceipt = false
    @State private var processingMessage = "Processing receipt..."
    @State private var prefilledAmount: Double?
    @State private var prefilledCategory: Category?
    @State private var prefilledDate: Date?
    @State private var capturedReceiptImage: UIImage?
    @State private var capturedMerchantName: String?
    @State private var selectedTab = 0
    @State private var showingOCRFailureAlert = false
    @State private var showingAPIKeyMissingAlert = false
    @State private var ocrErrorMessage = ""

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

                        // Tab 3: Reports
                        ReportListView()
                            .tabItem {
                                Label("Reports", systemImage: "doc.text")
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
                        prefilledAmount: prefilledAmount,
                        prefilledCategory: prefilledCategory,
                        prefilledDate: prefilledDate,
                        receiptImage: capturedReceiptImage,
                        merchantName: capturedMerchantName
                    )
                }
                .sheet(isPresented: $showingCameraReceipt) {
                    CameraReceiptView { capturedImage in
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
                        resetPrefilledData()
                        showingAddExpense = true
                    }

                    Button("Scan Receipt") {
                        if let apiKey = settings.first?.claudeAPIKey, !apiKey.isEmpty {
                            showingCameraReceipt = true
                        } else {
                            showingAPIKeyMissingAlert = true
                        }
                    }

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Choose how to add expense")
                }
                .alert("Claude API Key Required", isPresented: $showingAPIKeyMissingAlert) {
                    Button("Go to Settings") {
                        selectedTab = 4
                    }
                    Button("Manual Entry") {
                        resetPrefilledData()
                        showingAddExpense = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("To scan receipts, you need to configure your Claude API key in Settings. You can get a key from console.anthropic.com")
                }
                .alert("Unable to Read Receipt", isPresented: $showingOCRFailureAlert) {
                    Button("Retry") {
                        showingCameraReceipt = true
                    }
                    Button("Manual Entry") {
                        resetPrefilledData()
                        showingAddExpense = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(ocrErrorMessage)
                }
            }
        }
        .onAppear {
            initializeDataIfNeeded()
            requestNotificationPermissions()
        }
    }

    // MARK: - Computed Properties

    private var needsOnboarding: Bool {
        return settings.isEmpty || !settings[0].isComplete
    }

    // MARK: - Methods

    private func resetPrefilledData() {
        prefilledAmount = nil
        prefilledCategory = nil
        prefilledDate = nil
        capturedReceiptImage = nil
        capturedMerchantName = nil
    }

    private func initializeDataIfNeeded() {
        if categories.isEmpty {
            let predefinedCategories = Category.createPredefinedCategories()
            for category in predefinedCategories {
                modelContext.insert(category)
            }
            try? modelContext.save()
        } else {
            updateCategoryColorsIfNeeded()
        }
        cleanupSettingsIfNeeded()
    }

    private func cleanupSettingsIfNeeded() {
        if settings.count > 1 {
            if let completeSettings = settings.first(where: { $0.isComplete }) {
                for setting in settings where setting.id != completeSettings.id {
                    modelContext.delete(setting)
                }
            } else {
                for (index, setting) in settings.enumerated() {
                    if index < settings.count - 1 {
                        modelContext.delete(setting)
                    }
                }
            }
            try? modelContext.save()
        }

        if settings.isEmpty {
            let newSettings = YachtSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
        }
    }

    private func updateCategoryColorsIfNeeded() {
        let hasUpdatedCategories = UserDefaults.standard.bool(forKey: "hasUpdatedCategories_v5")
        guard !hasUpdatedCategories else { return }

        let colorMapping: [String: String] = [
            "Food": "#E53935",
            "Fuel": "#1E88E5",
            "Pharmacy": "#00897B",
            "Crew": "#D81B60",
            "Chandlery": "#FB8C00",
            "Water Test": "#03A9F4",
            "Welder": "#FF6F00",
            "Tender Fuel": "#607D8B",
            "Fly": "#00BCD4",
            "Supermarket": "#8BC34A"
        ]

        for category in categories where category.isPredefined {
            if let newColor = colorMapping[category.name] {
                category.colorHex = newColor
            }
        }

        let categoriesToRemove = ["Supplies", "Maintenance", "Mooring"]
        for category in categories where category.isPredefined {
            if categoriesToRemove.contains(category.name) {
                if let expenses = category.expenses, !expenses.isEmpty {
                    category.isPredefined = false
                } else {
                    modelContext.delete(category)
                }
            }
        }

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
        UserDefaults.standard.set(true, forKey: "hasUpdatedCategories_v5")
    }

    private func requestNotificationPermissions() {
        NotificationService.shared.requestAuthorization { granted in
            if granted {
                print("Notification permissions granted")
            }
        }
    }

    private func handleAddButtonTap() {
        showingAddMenu = true
    }

    private func processReceiptWithOCR(image: UIImage) async {
        await MainActor.run {
            processingMessage = "Analyzing receipt..."
        }

        guard let claudeAPIKey = settings.first?.claudeAPIKey, !claudeAPIKey.isEmpty else {
            await MainActor.run {
                isProcessingReceipt = false
                ocrErrorMessage = "Claude API key not configured. Please add your API key in Settings."
                showingOCRFailureAlert = true
            }
            return
        }

        let receiptData = await ReceiptOCRService.shared.processReceipt(
            image: image,
            claudeAPIKey: claudeAPIKey,
            learnedKeywords: learnedKeywords
        )

        var matchedCategory: Category?
        if let categoryName = receiptData.categoryName {
            matchedCategory = categories.first { $0.name == categoryName }
        }

        await MainActor.run {
            isProcessingReceipt = false

            if receiptData.amount == nil {
                ocrErrorMessage = "Could not extract amount from receipt. The photo may be blurry or the receipt format is not supported. Try again or enter manually."
                showingOCRFailureAlert = true
            } else {
                prefilledAmount = receiptData.amount
                prefilledCategory = matchedCategory
                prefilledDate = receiptData.date
                capturedMerchantName = receiptData.merchantName
                showingAddExpense = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, Category.self, YachtSettings.self])
}
