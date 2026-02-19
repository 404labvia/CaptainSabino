//
//  SettingsView.swift
//  YachtExpense
//
//  Impostazioni app e info yacht
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [YachtSettings]
    @Query private var learnedKeywords: [LearnedKeyword]
    @Query private var expenses: [Expense]
    @Query private var categories: [Category]

    @State private var showingEditSettings = false
    @State private var showingResetConfirmation = false

    // Accordion expansion state
    @State private var isYachtExpanded = true
    @State private var isExpensesExpanded = true
    @State private var isDataExpanded = true
    @State private var isScanningExpanded = true
    @State private var isAboutExpanded = false

    // Export/Import states
    @State private var showingExportShare = false
    @State private var exportFileURL: URL?
    @State private var showingImportPicker = false
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var isExporting = false

    // Yacht/Captain update confirmation
    @State private var showingUpdateConfirmation = false
    @State private var pendingYachtName = ""
    @State private var pendingCaptainName = ""

    private var yachtSettings: YachtSettings? {
        settings.first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                DisclosureGroup(isExpanded: $isYachtExpanded) {
                    yachtInfoContent
                } label: {
                    Label("Yacht Info", systemImage: "sailboat")
                        .fontWeight(.semibold)
                }

                DisclosureGroup(isExpanded: $isExpensesExpanded) {
                    expensesContent
                } label: {
                    Label("Expenses", systemImage: "cart")
                        .fontWeight(.semibold)
                }

                DisclosureGroup(isExpanded: $isDataExpanded) {
                    dataContent
                } label: {
                    Label("Data", systemImage: "externaldrive")
                        .fontWeight(.semibold)
                }

                DisclosureGroup(isExpanded: $isScanningExpanded) {
                    receiptScanningContent
                } label: {
                    Label("Receipt Scanning", systemImage: "viewfinder.circle")
                        .fontWeight(.semibold)
                }

                DisclosureGroup(isExpanded: $isAboutExpanded) {
                    aboutContent
                } label: {
                    Label("About", systemImage: "info.circle")
                        .fontWeight(.semibold)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditSettings) {
                EditSettingsView()
            }
            .confirmationDialog(
                "Reset Learned Keywords?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset (\(learnedKeywords.count) keywords)", role: .destructive) {
                    resetLearnedKeywords()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all learned keywords. The system will start learning again from scratch.")
            }
            .sheet(isPresented: $showingExportShare) {
                if let url = exportFileURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingImportPicker) {
                DocumentPicker(
                    contentTypes: [.json],
                    onPick: { url in
                        importDatabase(from: url)
                    }
                )
            }
            .alert("Import Completed", isPresented: $showingImportResult) {
                Button("OK") { }
            } message: {
                Text(importResultMessage)
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK") { }
            } message: {
                Text(importErrorMessage)
            }
            .alert("Update Yacht Info?", isPresented: $showingUpdateConfirmation) {
                Button("Update") {
                    updateYachtInfo()
                }
                Button("Keep Current", role: .cancel) { }
            } message: {
                Text("Do you want to update Yacht name and Captain name from the backup?")
            }
        }
    }

    // MARK: - Functions

    private func resetLearnedKeywords() {
        for keyword in learnedKeywords {
            modelContext.delete(keyword)
        }
        try? modelContext.save()
    }

    private func exportDatabase() {
        isExporting = true

        do {
            let url = try DatabaseExportService.shared.exportDatabase(
                expenses: expenses,
                categories: categories,
                learnedKeywords: Array(learnedKeywords),
                yachtName: yachtSettings?.yachtName ?? "Unknown",
                captainName: yachtSettings?.captainName ?? "Unknown",
                claudeAPIKey: yachtSettings?.claudeAPIKey
            )
            exportFileURL = url
            showingExportShare = true
        } catch {
            importErrorMessage = "Export failed: \(error.localizedDescription)"
            showingImportError = true
        }

        isExporting = false
    }

    private func importDatabase(from url: URL) {
        do {
            // Ottieni accesso sicuro al file
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.invalidFormat
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let result = try DatabaseExportService.shared.importDatabase(
                from: url,
                modelContext: modelContext,
                existingExpenses: Array(expenses),
                existingCategories: categories,
                existingKeywords: Array(learnedKeywords),
                yachtSettings: yachtSettings
            )

            importResultMessage = result.summary
            showingImportResult = true

            // Controlla se yacht/captain name sono diversi
            if let currentSettings = yachtSettings {
                let yachtDiffers = currentSettings.yachtName != result.yachtName
                let captainDiffers = currentSettings.captainName != result.captainName

                if yachtDiffers || captainDiffers {
                    pendingYachtName = result.yachtName
                    pendingCaptainName = result.captainName
                    // Mostra conferma dopo l'alert di import completato
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingUpdateConfirmation = true
                    }
                }
            }
        } catch {
            importErrorMessage = error.localizedDescription
            showingImportError = true
        }
    }

    private func updateYachtInfo() {
        guard let currentSettings = yachtSettings else { return }
        currentSettings.yachtName = pendingYachtName
        currentSettings.captainName = pendingCaptainName
        currentSettings.touch()
        try? modelContext.save()
    }

    // MARK: - View Components

    // Yacht Info group content
    @ViewBuilder
    private var yachtInfoContent: some View {
        if let s = yachtSettings {
            LabeledContent("Yacht", value: s.yachtName)
            LabeledContent("Captain", value: s.captainName)
            Button {
                showingEditSettings = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.gold)
                    Text("Edit Information")
                        .foregroundStyle(.primary)
                }
            }
        } else {
            Text("No settings configured")
                .foregroundStyle(.secondary)
        }
    }

    // Expenses group content (Categorie + Storage)
    @ViewBuilder
    private var expensesContent: some View {
        NavigationLink {
            ManageCategoriesView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(Color.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Manage Categories")
                        .foregroundStyle(.primary)
                    Text("\(customCategoriesCount) custom, \(predefinedCategoriesCount) predefined")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let currentSettings = yachtSettings {
            Toggle(isOn: Binding(
                get: { currentSettings.saveReceiptImages },
                set: {
                    currentSettings.saveReceiptImages = $0
                    try? modelContext.save()
                }
            )) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(Color.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save Receipt Images")
                            .foregroundStyle(.primary)
                        Text(storageUsedText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var customCategoriesCount: Int {
        categories.filter { !$0.isPredefined }.count
    }

    private var predefinedCategoriesCount: Int {
        categories.filter { $0.isPredefined }.count
    }

    private var storageUsedText: String {
        let bytes = ImageStorageService.shared.totalStorageUsed()
        if bytes == 0 { return "No images saved" }
        let mb = Double(bytes) / 1_048_576
        if mb < 1 {
            let kb = Double(bytes) / 1024
            return String(format: "%.0f KB used", kb)
        }
        return String(format: "%.1f MB used", mb)
    }

    // Data group content (Export + Import)
    @ViewBuilder
    private var dataContent: some View {
        Button {
            exportDatabase()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Database")
                        .foregroundStyle(.primary)
                    Text("\(expenses.count) expenses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isExporting {
                    ProgressView()
                }
            }
        }
        .disabled(expenses.isEmpty || isExporting)

        Button {
            showingImportPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(Color.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Database")
                        .foregroundStyle(.primary)
                    Text("From backup file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // Receipt Scanning group content
    @ViewBuilder
    private var receiptScanningContent: some View {
        if learnedKeywords.isEmpty {
            Text("No learned keywords yet")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        } else {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.gold)
                Text("Learned keywords")
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(learnedKeywords.count)")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Label("Reset learned keywords", systemImage: "arrow.counterclockwise")
            }
        }
    }

    // About group content
    @ViewBuilder
    private var aboutContent: some View {
        LabeledContent("Version", value: "1.0.0")
        LabeledContent("Build", value: "1")

        Link(destination: URL(string: "https://support.apple.com")!) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(Color.gold)
                Text("Support")
                    .foregroundStyle(.primary)
            }
        }

        Link(destination: URL(string: "https://www.apple.com/legal/privacy/")!) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .foregroundStyle(Color.gold)
                Text("Privacy Policy")
                    .foregroundStyle(.primary)
            }
        }
    }
}

// MARK: - Edit Settings View

struct EditSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [YachtSettings]

    @State private var yachtName = ""
    @State private var captainName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Yacht Information") {
                    TextField("Yacht", text: $yachtName)
                    TextField("Captain Name", text: $captainName)
                }
            }
            .navigationTitle("Edit Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private func loadCurrentSettings() {
        if let current = settings.first {
            yachtName = current.yachtName
            captainName = current.captainName
        }
    }

    private func saveSettings() {
        guard !yachtName.isEmpty else {
            showAlert("Please enter yacht name")
            return
        }

        guard !captainName.isEmpty else {
            showAlert("Please enter captain name")
            return
        }

        if let current = settings.first {
            current.yachtName = yachtName
            current.captainName = captainName
            current.touch()
        }

        try? modelContext.save()
        dismiss()
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Claude API Settings View

struct ClaudeAPISettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [YachtSettings]

    @State private var apiKey = ""
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-api03-...", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            } header: {
                Label("API Key", systemImage: "key")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API is required to scan receipts.")
                    Text("Get your API key from console.anthropic.com")
                        .foregroundColor(.blue)
                }
            }

            Section("Cost Estimate") {
                LabeledContent("Per receipt scan", value: "~€0.003")
                LabeledContent("100 receipts/month", value: "~€0.30")
            }

            if !apiKey.isEmpty {
                Section {
                    Button("Clear API Key", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("Claude API")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveAPIKey()
                }
                .fontWeight(.semibold)
                .disabled(apiKey.isEmpty)
            }
        }
        .confirmationDialog("Clear API Key?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                apiKey = ""
                saveAPIKey()
            }
        }
        .onAppear {
            if let currentKey = settings.first?.claudeAPIKey {
                apiKey = currentKey
            }
        }
    }

    private func saveAPIKey() {
        if let currentSettings = settings.first {
            currentSettings.claudeAPIKey = apiKey.isEmpty ? nil : apiKey
            currentSettings.touch()
            try? modelContext.save()
        }
        dismiss()
    }
}

// MARK: - DocumentPicker (UIKit wrapper per selezione file)

struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [YachtSettings.self, Expense.self, Category.self])
}
