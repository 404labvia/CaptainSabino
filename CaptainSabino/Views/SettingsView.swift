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
    @State private var showAPISection = false
    @State private var tapCount = 0

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
                yachtInfoSection
                dataManagementSection
                if showAPISection {
                    receiptScanningSection
                }
                appInfoSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.headline)
                        .onTapGesture {
                            tapCount += 1
                            if tapCount >= 5 {
                                withAnimation {
                                    showAPISection.toggle()
                                }
                                tapCount = 0
                            }
                            // Reset counter dopo 2 secondi se non si raggiunge il target
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if tapCount < 5 {
                                    tapCount = 0
                                }
                            }
                        }
                }
            }
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

    private var yachtInfoSection: some View {
        Section("Yacht Information") {
            if let settings = yachtSettings {
                LabeledContent("Yacht", value: settings.yachtName)
                LabeledContent("Captain", value: settings.captainName)

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
    }

    private var dataManagementSection: some View {
        Section {
            // Export
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

            // Import
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
        } header: {
            Text("Data Management")
        } footer: {
            Text("Export creates a backup file you can share via AirDrop, email, or save to Files. Import merges data without duplicating existing expenses.")
        }
    }

    private var receiptScanningSection: some View {
        Section {
            if let settings = yachtSettings {
                NavigationLink {
                    ClaudeAPISettingsView()
                } label: {
                    HStack {
                        Image(systemName: "key")
                            .foregroundStyle(Color.gold)
                        Text("Claude API Key")
                            .foregroundStyle(.primary)
                        Spacer()
                        if let apiKey = settings.claudeAPIKey, !apiKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Text("Required")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }

                if !learnedKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
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

            } else {
                Text("No settings configured")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Receipt Scanning")
        } footer: {
            Text("Claude API is required to scan receipts. The system learns from your category choices to improve accuracy over time.")
        }
    }

    private var appInfoSection: some View {
        Section("About") {
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
