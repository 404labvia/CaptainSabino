//
//  AddExpenseView.swift
//  YachtExpense
//
//  Form per aggiungere nuova spesa
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]
    @Query private var settings: [YachtSettings]
    @Query private var learnedKeywords: [LearnedKeyword]
    @Query private var existingExpenses: [Expense]

    // Prefilled data from OCR (optional)
    var prefilledAmount: Double?
    var prefilledCategory: Category?
    var prefilledDate: Date?
    var receiptImage: UIImage?
    var merchantName: String?

    // Callback per flusso fotocamera continuo (chiamato dopo salvataggio)
    var onSaveCompleted: (() -> Void)?

    @State private var amount = ""
    @State private var selectedCategory: Category?
    @State private var date = Date()
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDatePicker = false
    @State private var isPossibleDuplicate = false
    @State private var tempSelectedDate = Date()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Amount Section
                    amountSection

                    // Date Section (sotto Amount)
                    dateSection

                    // Category Section
                    categorySection

                    // Notes Section
                    notesSection

                    // Badge duplicato (se rilevato)
                    if isPossibleDuplicate {
                        duplicateBadge
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottone Save giallo fisso in basso
                Button {
                    saveExpense()
                } label: {
                    Text("Save Expense")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(.systemGroupedBackground))
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker(
                        "Select Date",
                        selection: $tempSelectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .navigationTitle("Select Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("OK") {
                                date = tempSelectedDate
                                checkForDuplicate()
                                showingDatePicker = false
                            }
                            .fontWeight(.semibold)
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                showingDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
                .onAppear {
                    tempSelectedDate = date
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadPrefilledData()
            }
            .onChange(of: amount) { _, _ in
                checkForDuplicate()
            }
            .onChange(of: date) { _, _ in
                checkForDuplicate()
            }
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

            // Quick buttons + calendario (più recente a destra)
            HStack(spacing: 12) {
                // Calendario (a sinistra)
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

                // Oggi (più recente, a destra)
                QuickDateButton(
                    date: Date(),
                    isSelected: isSameDay(date, Date())
                ) {
                    date = Date()
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

    /// Badge per possibile duplicato
    private var duplicateBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)

            Text("Possible Duplicate")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red)
        .cornerRadius(8)
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

    private func loadPrefilledData() {
        // Load prefilled amount
        if let prefilledAmount = prefilledAmount {
            amount = String(format: "%.2f", prefilledAmount)
        }

        // Load prefilled category
        if let prefilledCategory = prefilledCategory {
            selectedCategory = prefilledCategory
        }

        // Load prefilled date
        if let prefilledDate = prefilledDate {
            date = prefilledDate
        }

        // Verifica duplicato dopo aver caricato i dati prefilled
        checkForDuplicate()
    }

    /// Verifica se esiste una spesa con stesso importo e stessa data
    private func checkForDuplicate() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
            isPossibleDuplicate = false
            return
        }

        let calendar = Calendar.current
        isPossibleDuplicate = existingExpenses.contains { expense in
            abs(expense.amount - amountValue) < 0.01 &&
            calendar.isDate(expense.date, inSameDayAs: date)
        }
    }

    private func saveExpense() {
        // Validate amount
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              amountValue > 0 else {
            showAlert("Please enter a valid amount greater than 0")
            return
        }

        // Validate category
        guard let selectedCategory = selectedCategory else {
            showAlert("Please select a category")
            return
        }

        // Create and save expense
        let newExpense = Expense(
            amount: amountValue,
            category: selectedCategory,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(newExpense)

        // MACHINE LEARNING: Learn keywords from merchant name
        if let merchantName = merchantName, !merchantName.isEmpty {
            learnKeywordsFromMerchant(merchantName: merchantName, categoryName: selectedCategory.name)
        }

        do {
            try modelContext.save()
            dismiss()
            onSaveCompleted?()
        } catch {
            showAlert("Failed to save expense: \(error.localizedDescription)")
        }
    }

    /// Impara keyword dal nome merchant e le associa alla categoria scelta
    private func learnKeywordsFromMerchant(merchantName: String, categoryName: String) {
        let keywords = ReceiptOCRService.shared.extractMerchantKeywords(from: merchantName)

        guard !keywords.isEmpty else { return }

        for keyword in keywords {
            if let existing = learnedKeywords.first(where: {
                $0.keyword == keyword && $0.categoryName == categoryName
            }) {
                existing.usageCount += 1
                existing.lastUsedDate = Date()
            } else {
                let learned = LearnedKeyword(
                    categoryName: categoryName,
                    keyword: keyword,
                    learnedDate: Date(),
                    usageCount: 1,
                    lastUsedDate: Date()
                )
                modelContext.insert(learned)
            }
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Custom Components

/// Grid Item per categoria con icona e nome
struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Icona
            ZStack {
                Circle()
                    .fill(isSelected ? category.color : category.color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : category.color)
            }

            // Nome categoria
            Text(category.name)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? category.color : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? category.color.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? category.color : Color.clear, lineWidth: 2)
        )
    }
}

/// Quick Date Button con formato breve
struct QuickDateButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(shortFormattedDate(date))
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .blue : .primary)
                .frame(width: 60, height: 44)
                .background(
                    isSelected
                        ? Color.blue.opacity(0.1)
                        : Color(.tertiarySystemGroupedBackground)
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                )
        }
    }

    private func shortFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    AddExpenseView()
        .modelContainer(for: [Expense.self, Category.self])
}
