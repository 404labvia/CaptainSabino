//
//  EditExpenseView.swift
//  YachtExpense
//
//  Form per modificare spesa esistente
//

import SwiftUI
import SwiftData

struct EditExpenseView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]

    let expense: Expense

    @State private var amount: String
    @State private var selectedCategory: Category?
    @State private var date: Date
    @State private var notes: String
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDatePicker = false

    // MARK: - Initializer

    init(expense: Expense) {
        self.expense = expense
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _selectedCategory = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
        _notes = State(initialValue: expense.notes)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Amount Section
                amountSection

                // Category Section
                categorySection

                // Date Section
                dateSection

                // Notes Section
                notesSection

                // Delete Section
                deleteSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    updateExpense()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePicker(
                "Select Date",
                selection: $date,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Expense?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteExpense()
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

    // MARK: - View Components

    /// Amount Section - Centrale con font grande
    private var amountSection: some View {
        VStack(spacing: 8) {
            Text("AMOUNT")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("€")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.title)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// Category Section - Griglia 3x4 con icone
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { category in
                    CategoryGridItem(
                        category: category,
                        isSelected: selectedCategory?.id == category.id
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// Date Section - Data centrale + quick buttons + calendario
    private var dateSection: some View {
        VStack(spacing: 12) {
            Text("DATE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Data selezionata (centrale)
            Text(formattedDate(date))
                .font(.title3)
                .fontWeight(.semibold)

            // Quick buttons + calendario
            HStack(spacing: 12) {
                // 2 giorni fa
                QuickDateButton(
                    date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                    isSelected: isSameDay(date, Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date())
                ) {
                    date = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
                }

                // Ieri
                QuickDateButton(
                    date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                    isSelected: isSameDay(date, Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
                ) {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                }

                // Oggi
                QuickDateButton(
                    date: Date(),
                    isSelected: isSameDay(date, Date())
                ) {
                    date = Date()
                }

                // Calendario
                Button {
                    showingDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 60, height: 44)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// Notes Section - Una riga
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES (OPTIONAL)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextEditor(text: $notes)
                .frame(height: 44)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// Delete Section
    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteAlert = true
        } label: {
            HStack {
                Spacer()
                Label("Delete Expense", systemImage: "trash")
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Helper Methods

    /// Formatta data come "30 Nov 2025"
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// Controlla se due date sono lo stesso giorno
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }

    // MARK: - Methods

    private func updateExpense() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              amountValue > 0 else {
            showAlert("Please enter a valid amount")
            return
        }

        guard let selectedCategory = selectedCategory else {
            showAlert("Please select a category")
            return
        }

        expense.amount = amountValue
        expense.category = selectedCategory
        expense.date = date
        expense.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            showAlert("Failed to update expense: \(error.localizedDescription)")
        }
    }

    private func deleteExpense() {
        modelContext.delete(expense)
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
        EditExpenseView(expense: Expense.sampleExpenses[0])
            .modelContainer(for: [Expense.self, Category.self])
    }
}
