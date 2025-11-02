//
//  ReminderListView.swift
//  YachtExpense
//
//  Lista promemoria e scadenze
//

import SwiftUI
import SwiftData

struct ReminderListView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.dueDate, order: .forward) private var reminders: [Reminder]
    
    @State private var showingAddReminder = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if reminders.isEmpty {
                    emptyStateView
                } else {
                    reminderListView
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddReminder.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var activeReminders: [Reminder] {
        reminders.filter { !$0.isCompleted }
    }
    
    private var completedReminders: [Reminder] {
        reminders.filter { $0.isCompleted }
    }
    
    // MARK: - View Components
    
    private var reminderListView: some View {
        List {
            if !activeReminders.isEmpty {
                Section("Active") {
                    ForEach(activeReminders) { reminder in
                        NavigationLink {
                            EditReminderView(reminder: reminder)
                        } label: {
                            ReminderRowView(reminder: reminder)
                        }
                    }
                    .onDelete(perform: deleteReminders)
                }
            }
            
            if !completedReminders.isEmpty {
                Section("Completed") {
                    ForEach(completedReminders) { reminder in
                        NavigationLink {
                            EditReminderView(reminder: reminder)
                        } label: {
                            ReminderRowView(reminder: reminder)
                        }
                    }
                    .onDelete(perform: deleteReminders)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 70))
                .foregroundStyle(.gray)
            
            Text("No Reminders")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to add a reminder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                showingAddReminder.toggle()
            } label: {
                Label("Add Reminder", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Methods
    
    private func deleteReminders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(reminders[index])
        }
    }
}

// MARK: - Reminder Row View

struct ReminderRowView: View {
    let reminder: Reminder
    
    var body: some View {
        HStack(spacing: 15) {
            // Status Icon
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
                
                if reminder.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                    .strikethrough(reminder.isCompleted)
                
                if !reminder.notes.isEmpty {
                    Text(reminder.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    
                    Text(reminder.formattedDueDate)
                        .font(.caption)
                    
                    Text("•")
                        .font(.caption)
                    
                    Text(reminder.statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .opacity(reminder.isCompleted ? 0.6 : 1.0)
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        if reminder.isCompleted {
            return .green
        } else if reminder.isOverdue {
            return .red
        } else {
            return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    ReminderListView()
        .modelContainer(for: [Reminder.self])
}
