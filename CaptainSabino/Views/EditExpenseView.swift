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
    @Query private var existingExpenses: [Expense]

    let expense: Expense

    @State private var amount: String
    @State private var merchant: String
    @State private var selectedCategory: Category?
    @State private var date: Date
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDatePicker = false
    @State private var showMerchantSuggestions = false

    // MARK: - Initializer

    init(expense: Expense) {
        self.expense = expense
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _merchant = State(initialValue: expense.merchantName)
        _selectedCategory = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Amount Section
                    amountSection

                    // Merchant Section
                    merchantSection

                    // Date Section (con scroll orizzontale)
                    dateSection

                    // Category Section
                    categorySection

                    // Delete Section
                    deleteSection

                    // Spazio per il bottone fisso in basso
                    Spacer().frame(height: 100)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))

            // Save Button fisso in basso
            VStack {
                Spacer()
                saveButtonSection
            }
        }
        .navigationTitle("Edit Expense")
        .navigationBarTitleDisplayMode(.inline)
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

    /// Merchant Section - Campo con autocomplete
    private var merchantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MERCHANT")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    // Campo di input
                    TextField("Store or supplier name", text: $merchant)
                        .textInputAutocapitalization(.words)
                        .padding(12)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                        .onChange(of: merchant) { _, newValue in
                            showMerchantSuggestions = newValue.count >= 3 && !filteredMerchants.isEmpty
                        }

                    // Lista suggerimenti
                    if showMerchantSuggestions && !filteredMerchants.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(filteredMerchants.prefix(5), id: \.self) { suggestion in
                                Button {
                                    merchant = suggestion
                                    showMerchantSuggestions = false
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(suggestion)
                                            .foregroundStyle(Color.royalBlue)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(.tertiarySystemGroupedBackground))
                                }
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// Merchants già usati, filtrati per testo inserito (con Title Case)
    private var filteredMerchants: [String] {
        let allMerchants = Set(existingExpenses.compactMap { exp -> String? in
            let name = exp.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name.toTitleCase()
        })

        let searchText = merchant.lowercased()
        return allMerchants
            .filter { $0.lowercased().contains(searchText) }
            .sorted()
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

    /// Date Section - Calendario fisso + scroll orizzontale 14 giorni
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

            // Calendario fisso + scroll orizzontale date
            HStack(spacing: 8) {
                // Calendario (fisso a sinistra)
                Button {
                    showingDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(Color.royalBlue)
                        .frame(width: 50, height: 44)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                }

                // Scroll orizzontale 14 giorni (oggi a destra)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<14, id: \.self) { daysAgo in
                                let buttonDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                                QuickDateButton(
                                    date: buttonDate,
                                    isSelected: isSameDay(date, buttonDate)
                                ) {
                                    date = buttonDate
                                }
                                .id(daysAgo)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onAppear {
                        // Scroll alla data selezionata
                        let selectedDaysAgo = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                        if selectedDaysAgo >= 0 && selectedDaysAgo < 14 {
                            proxy.scrollTo(selectedDaysAgo, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
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

    /// Save Button fisso in basso (stile premium giallo)
    private var saveButtonSection: some View {
        VStack(spacing: 8) {
            Button {
                updateExpense()
            } label: {
                Text("Save Expense")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.premiumYellow)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 20)
        .background(
            Color(.systemGroupedBackground)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
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
        expense.merchantName = merchant.trimmingCharacters(in: .whitespacesAndNewlines)

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
