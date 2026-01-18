//
//  OnboardingView.swift
//  YachtExpense
//
//  Schermata di configurazione iniziale
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct OnboardingView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [YachtSettings]
    @Query private var categories: [Category]
    @Query private var learnedKeywords: [LearnedKeyword]

    @State private var yachtName = ""
    @State private var captainName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // Import states
    @State private var showingImportPicker = false
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var showingImportError = false
    @State private var importErrorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Navy Blue background
                Color.navy
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        headerSection

                        // Form
                        formSection

                        // Buttons
                        buttonsSection

                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
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
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 15) {
            Text("Onboarding")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.cream)

            Text("Let's set up your yacht information")
                .font(.subheadline)
                .foregroundStyle(Color.cream.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            // Yacht Name
            VStack(alignment: .leading, spacing: 8) {
                Label("Yacht", systemImage: "sailboat")
                    .font(.headline)
                TextField("Enter yacht name", text: $yachtName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            // Captain Name
            VStack(alignment: .leading, spacing: 8) {
                Label("Captain Name", systemImage: "person.badge.shield.checkmark")
                    .font(.headline)
                TextField("Enter captain name", text: $captainName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
    }

    private var buttonsSection: some View {
        VStack(spacing: 16) {
            // Get Started button
            Button(action: saveSettings) {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.royalBlue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gold)
                    .cornerRadius(12)
            }

            // Import Database button
            Button {
                showingImportPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(Color.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Database")
                            .foregroundStyle(Color.cream)
                        Text("From backup file")
                            .font(.caption)
                            .foregroundStyle(Color.cream.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Methods

    private func saveSettings() {
        // Validation
        guard !yachtName.isEmpty else {
            showAlert("Please enter yacht name")
            return
        }

        guard !captainName.isEmpty else {
            showAlert("Please enter captain name")
            return
        }

        // Save or update settings
        do {
            if let existingSettings = settings.first {
                existingSettings.yachtName = yachtName
                existingSettings.captainName = captainName
                existingSettings.touch()
            } else {
                let newSettings = YachtSettings(
                    yachtName: yachtName,
                    captainName: captainName,
                    claudeAPIKey: nil
                )
                modelContext.insert(newSettings)
            }

            try modelContext.save()
            print("✅ Settings saved successfully")
            print("✅ Settings complete: \(settings.first?.isComplete ?? false)")
        } catch {
            print("❌ Error saving settings: \(error)")
            showAlert("Error saving settings: \(error.localizedDescription)")
        }
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
                existingCategories: categories,
                existingKeywords: Array(learnedKeywords),
                yachtSettings: settings.first
            )

            // Auto-fill yacht and captain name from imported data
            if yachtName.isEmpty {
                yachtName = result.yachtName
            }
            if captainName.isEmpty {
                captainName = result.captainName
            }

            importResultMessage = result.summary
            showingImportResult = true
        } catch {
            importErrorMessage = error.localizedDescription
            showingImportError = true
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(for: [YachtSettings.self, Category.self, LearnedKeyword.self])
}
