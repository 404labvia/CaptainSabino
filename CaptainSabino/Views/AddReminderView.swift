//
//  AddReminderView.swift
//  YachtExpense
//
//  Form per aggiungere nuovo promemoria
//

import SwiftUI
import SwiftData

struct AddReminderView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder Title") {
                    TextField("e.g., Insurance Renewal", text: $title)
                }
                
                Section("Due Date") {
                    DatePicker(
                        "Date and Time",
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveReminder()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Methods
    
    private func saveReminder() {
        guard !title.isEmpty else {
            showAlert("Please enter a title")
            return
        }
        
        guard dueDate > Date() else {
            showAlert("Please select a future date")
            return
        }
        
        let newReminder = Reminder(
            title: title,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate
        )
        
        modelContext.insert(newReminder)
        
        do {
            try modelContext.save()
            
            // Schedule notification
            NotificationService.shared.scheduleReminder(newReminder)
            
            dismiss()
        } catch {
            showAlert("Failed to save reminder: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Preview

#Preview {
    AddReminderView()
        .modelContainer(for: [Reminder.self])
}
