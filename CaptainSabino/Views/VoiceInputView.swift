//
//  VoiceInputView.swift
//  CaptainSabino
//
//  View per l'input vocale delle spese
//

import SwiftUI
import SwiftData

struct VoiceInputView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]

    @StateObject private var voiceService = VoiceInputService.shared

    // Callback to pass parsed data to parent
    var onExpenseParsed: ((Double?, Category?) -> Void)?

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var authorizationRequested = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // Microphone Animation
                microphoneIcon

                // Status Text
                statusText

                // Transcribed Text
                transcribedTextView

                Spacer()

                // Record Button
                recordButton

                // Confirm Button (appears after recording)
                if !voiceService.transcribedText.isEmpty && !voiceService.isRecording {
                    confirmButton
                }
            }
            .padding()
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if voiceService.isRecording {
                            voiceService.stopRecording()
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                requestAuthorizationIfNeeded()
            }
            .onDisappear {
                resetVoiceInput()
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - View Components

    private var microphoneIcon: some View {
        ZStack {
            // Pulsating circles when recording
            if voiceService.isRecording {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 150, height: 150)
                    .scaleEffect(voiceService.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: voiceService.isRecording)

                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .scaleEffect(voiceService.isRecording ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: voiceService.isRecording)
            }

            // Microphone icon
            ZStack {
                Circle()
                    .fill(voiceService.isRecording ? Color.blue : Color.gray.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: voiceService.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 50))
                    .foregroundStyle(voiceService.isRecording ? .white : .blue)
            }
        }
    }

    private var statusText: some View {
        Text(voiceService.isRecording ? "Listening..." : "Tap to start recording")
            .font(.title3)
            .fontWeight(.medium)
            .foregroundStyle(voiceService.isRecording ? .blue : .secondary)
    }

    private var transcribedTextView: some View {
        Group {
            if !voiceService.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recognized:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(voiceService.transcribedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                }
            }
        }
    }

    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            HStack {
                Image(systemName: voiceService.isRecording ? "stop.fill" : "waveform")
                    .font(.title3)
                Text(voiceService.isRecording ? "Stop Recording" : "Start Recording")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(voiceService.isRecording ? Color.red : Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
    }

    private var confirmButton: some View {
        Button {
            processVoiceInput()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Continue")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Methods

    private func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else { return }
        authorizationRequested = true

        voiceService.requestAuthorization { granted in
            if !granted {
                showAlert("Speech recognition permission is required to use voice input. Please enable it in Settings.")
            }
        }
    }

    private func toggleRecording() {
        if voiceService.isRecording {
            voiceService.stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard voiceService.checkAuthorization() else {
            showAlert("Speech recognition permission denied. Please enable it in Settings.")
            return
        }

        do {
            try voiceService.startRecording()
        } catch {
            showAlert("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func processVoiceInput() {
        let text = voiceService.transcribedText

        // Parse amount and category
        let (amount, categoryName) = voiceService.parseExpenseFromText(text)

        // Find category by name
        let parsedCategory: Category?
        if let categoryName = categoryName {
            parsedCategory = categories.first { $0.name == categoryName }
        } else {
            parsedCategory = nil
        }

        // Pass data to parent via callback
        onExpenseParsed?(amount, parsedCategory)

        // Dismiss current view
        dismiss()
    }

    private func resetVoiceInput() {
        // Reset voice service state when view disappears
        if voiceService.isRecording {
            voiceService.stopRecording()
        }
        voiceService.transcribedText = ""
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Preview

#Preview {
    VoiceInputView()
        .modelContainer(for: [Category.self, Expense.self])
}
