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
    @Query private var learnedKeywords: [LearnedKeyword]

    @State private var showingEditSettings = false
    @State private var showingResetConfirmation = false

    private var yachtSettings: YachtSettings? {
        settings.first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                yachtInfoSection
                receiptScanningSection
                appInfoSection
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
        }
    }

    // MARK: - Functions

    private func resetLearnedKeywords() {
        for keyword in learnedKeywords {
            modelContext.delete(keyword)
        }
        try? modelContext.save()
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
                NavigationLink {
                    ClaudeAPISettingsView()
                } label: {
                    HStack {
                        Label("Claude API Key", systemImage: "key")
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
                            Label("Learned keywords", systemImage: "brain.head.profile")
                                .foregroundColor(.blue)
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

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [YachtSettings.self])
}
