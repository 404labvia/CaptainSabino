//
//  EditReminderView.swift
//  YachtExpense
//
//  Form per modificare promemoria esistente
//

import SwiftUI
import SwiftData

struct EditReminderView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let reminder: Reminder
    
    @State private var title: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var isCompleted: Bool
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Initializer
    
    init(reminder: Reminder) {
        self.reminder = reminder
        _title = State(initialValue: reminder.title)
        _notes = State(initialValue: reminder.notes)
        _dueDate = State(initialValue: reminder.dueDate)
        _isCompleted = State(initialValue: reminder.isCompleted)
    }
    
    // MARK: - Body
    
    var body: some View {
        Form {
            Section("Title") {
                TextField("Reminder title", text: $title)
            }
            
            Section("Due Date") {
                DatePicker(
                    "Date and Time",
                    selection: $dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(height: 100)
            }
            
            Section {
                Toggle("Completed", isOn: $isCompleted)
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Reminder")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    updateReminder()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Delete Reminder?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteReminder()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Methods
    
    private func updateReminder() {
        guard !title.isEmpty else {
            showAlert("Please enter a title")
            return
        }
        
        // Cancel old notification
        if let notificationId = reminder.notificationId {
            NotificationService.shared.cancelNotification(notificationId)
        }
        
        reminder.title = title
        reminder.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.dueDate = dueDate
        reminder.isCompleted = isCompleted
        
        do {
            try modelContext.save()
            
            // Reschedule if not completed
            if !isCompleted {
                NotificationService.shared.scheduleReminder(reminder)
            }
            
            dismiss()
        } catch {
            showAlert("Failed to update reminder: \(error.localizedDescription)")
        }
    }
    
    private func deleteReminder() {
        // Cancel notification
        if let notificationId = reminder.notificationId {
            NotificationService.shared.cancelNotification(notificationId)
        }
        
        modelContext.delete(reminder)
        dismiss()
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditReminderView(reminder: Reminder.sampleReminders[0])
            .modelContainer(for: [Reminder.self])
    }
}
