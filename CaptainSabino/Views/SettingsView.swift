//
//  SettingsView.swift
//  YachtExpense
//
//  Impostazioni app e info yacht
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [YachtSettings]
    
    @State private var showingEditSettings = false
    
    private var yachtSettings: YachtSettings? {
        settings.first
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Yacht Info Section
                yachtInfoSection

                // Receipt Scanning Section
                receiptScanningSection

                // App Info Section
                appInfoSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditSettings) {
                EditSettingsView()
            }
        }
    }
    
    // MARK: - View Components
    
    private var yachtInfoSection: some View {
        Section("Yacht Information") {
            if let settings = yachtSettings {
                LabeledContent("Yacht", value: settings.yachtName)
                LabeledContent("Owner Email", value: settings.ownerEmail)
                LabeledContent("Captain", value: settings.captainName)
                LabeledContent("Captain Email", value: settings.captainEmail)

                Button {
                    showingEditSettings = true
                } label: {
                    Label("Edit Information", systemImage: "pencil")
                }
            } else {
                Text("No settings configured")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var receiptScanningSection: some View {
        Section {
            if let settings = yachtSettings {
                Toggle("Sync receipts to iCloud", isOn: Binding(
                    get: { settings.syncReceiptsToiCloud },
                    set: { newValue in
                        settings.syncReceiptsToiCloud = newValue
                        settings.touch()
                        try? modelContext.save()

                        // Migra foto se necessario
                        if newValue {
                            ReceiptStorageService.shared.migrateReceipts(toICloud: true)
                        } else {
                            ReceiptStorageService.shared.migrateReceipts(toICloud: false)
                        }
                    }
                ))

                // Storage usage
                let localStorage = ReceiptStorageService.shared.getStorageUsed(useICloud: false)
                let iCloudStorage = ReceiptStorageService.shared.getStorageUsed(useICloud: true)

                LabeledContent("Local storage", value: localStorage.formattedByteSize)
                LabeledContent("iCloud storage", value: iCloudStorage.formattedByteSize)

            } else {
                Text("No settings configured")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Receipt Scanning")
        } footer: {
            Text("Enable iCloud sync to access receipt photos across all your devices")
        }
    }

    private var appInfoSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Build", value: "1")

            Link(destination: URL(string: "https://support.apple.com")!) {
                Label("Support", systemImage: "questionmark.circle")
            }

            Link(destination: URL(string: "https://www.apple.com/legal/privacy/")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
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
    @State private var ownerEmail = ""
    @State private var captainName = ""
    @State private var captainEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Yacht Information") {
                    TextField("Yacht", text: $yachtName)
                    TextField("Owner Email", text: $ownerEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Captain Name", text: $captainName)
                    TextField("Captain Email", text: $captainEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
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
            ownerEmail = current.ownerEmail
            captainName = current.captainName
            captainEmail = current.captainEmail
        }
    }
    
    private func saveSettings() {
        guard !yachtName.isEmpty else {
            showAlert("Please enter yacht name")
            return
        }

        guard !ownerEmail.isEmpty, ownerEmail.contains("@") else {
            showAlert("Please enter a valid owner email")
            return
        }

        guard !captainEmail.isEmpty, captainEmail.contains("@") else {
            showAlert("Please enter a valid captain email")
            return
        }

        if let current = settings.first {
            current.yachtName = yachtName
            current.ownerEmail = ownerEmail
            current.captainName = captainName
            current.captainEmail = captainEmail
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

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [YachtSettings.self])
}
