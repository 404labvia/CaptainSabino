//
//  OnboardingView.swift
//  YachtExpense
//
//  Schermata di configurazione iniziale
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [YachtSettings]
    
    @State private var yachtName = ""
    @State private var captainName = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        headerSection
                        
                        // Form
                        formSection
                        
                        // Save Button
                        saveButton
                        
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
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "sailboat")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Welcome to YachtExpense")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Let's set up your yacht information")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
    
    private var saveButton: some View {
        Button(action: saveSettings) {
            Text("Get Started")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
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
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(for: [YachtSettings.self])
}
