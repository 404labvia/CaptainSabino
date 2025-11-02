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
                
                // Exchange Rate Section
                exchangeRateSection
                
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
                LabeledContent("Yacht Name", value: settings.yachtName)
                LabeledContent("Owner", value: settings.ownerName)
                LabeledContent("Owner Email", value: settings.ownerEmail)
                LabeledContent("Captain", value: settings.captainName)
                
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
    
    private var exchangeRateSection: some View {
        Section {
            if let settings = yachtSettings {
                LabeledContent("EUR to USD", value: String(format: "%.2f", settings.exchangeRateEURtoUSD))
            }
        } header: {
            Text("Exchange Rate (Fixed)")
        } footer: {
            Text("This is a fixed exchange rate used for reference only")
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
    @State private var ownerName = ""
    @State private var ownerEmail = ""
    @State private var captainName = ""
    @State private var exchangeRate = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Yacht Information") {
                    TextField("Yacht Name", text: $yachtName)
                    TextField("Owner Name", text: $ownerName)
                    TextField("Owner Email", text: $ownerEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Captain Name", text: $captainName)
                }
                
                Section {
                    TextField("1.10", text: $exchangeRate)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Exchange Rate")
                } footer: {
                    Text("EUR to USD fixed rate")
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
            ownerName = current.ownerName
            ownerEmail = current.ownerEmail
            captainName = current.captainName
            exchangeRate = String(format: "%.2f", current.exchangeRateEURtoUSD)
        }
    }
    
    private func saveSettings() {
        guard !yachtName.isEmpty else {
            showAlert("Please enter yacht name")
            return
        }
        
        guard !ownerEmail.isEmpty, ownerEmail.contains("@") else {
            showAlert("Please enter a valid email")
            return
        }
        
        guard let rateValue = Double(exchangeRate.replacingOccurrences(of: ",", with: ".")),
              rateValue > 0 else {
            showAlert("Please enter a valid exchange rate")
            return
        }
        
        if let current = settings.first {
            current.yachtName = yachtName
            current.ownerName = ownerName
            current.ownerEmail = ownerEmail
            current.captainName = captainName
            current.exchangeRateEURtoUSD = rateValue
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
