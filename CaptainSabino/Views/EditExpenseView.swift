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
        Form {
            // Amount Section
            Section("Amount") {
                HStack {
                    Text("€")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }
            }
            
            // Category Section
            Section("Category") {
                Picker("Select Category", selection: $selectedCategory) {
                    Text("Select...").tag(nil as Category?)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.icon)
                            .tag(category as Category?)
                    }
                }
            }
            
            // Date Section
            Section("Date") {
                DatePicker(
                    "Expense Date",
                    selection: $date,
                    displayedComponents: [.date]
                )
            }
            
            // Notes Section
            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(height: 100)
            }
            
            // Delete Section
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Expense")
                        Spacer()
                    }
                }
            }
        }
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
