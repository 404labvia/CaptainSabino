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

    // Prefilled data from voice input or OCR (optional)
    var prefilledAmount: Double?
    var prefilledCategory: Category?
    var receiptImage: UIImage?
    var ocrText: String? // Testo OCR per learning delle keyword

    @State private var amount = ""
    @State private var selectedCategory: Category?
    @State private var date = Date()
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDatePicker = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
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

                    // Receipt Photo Section (if present)
                    if receiptImage != nil {
                        receiptPhotoSection
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveExpense()
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
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadPrefilledData()
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

    /// Category Section - Griglia 4 colonne con icone
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            let columns = [
                GridItem(.flexible()),
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
                // Oggi (prima posizione)
                QuickDateButton(
                    date: Date(),
                    isSelected: isSameDay(date, Date())
                ) {
                    date = Date()
                }

                // Ieri
                QuickDateButton(
                    date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                    isSelected: isSameDay(date, Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
                ) {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                }

                // 2 giorni fa
                QuickDateButton(
                    date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                    isSelected: isSameDay(date, Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date())
                ) {
                    date = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
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

    /// Receipt Photo Section
    private var receiptPhotoSection: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

            Text("Receipt photo attached")
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "photo")
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods

    /// Formatta data come "30 Nov"
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// Formatta data breve come "30 Nov"
    private func shortFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
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

        // Save receipt photo if present
        var receiptImagePath: String?
        if let receiptImage = receiptImage {
            let useICloud = settings.first?.syncReceiptsToiCloud ?? false
            receiptImagePath = ReceiptStorageService.shared.saveReceipt(
                image: receiptImage,
                date: date,
                amount: amountValue,
                categoryName: selectedCategory.name,
                useICloud: useICloud
            )
        }

        // Create and save expense
        let newExpense = Expense(
            amount: amountValue,
            category: selectedCategory,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImagePath: receiptImagePath
        )

        modelContext.insert(newExpense)

        // MACHINE LEARNING: Learn keywords from OCR text
        if let ocrText = ocrText, !ocrText.isEmpty {
            learnKeywordsFromReceipt(ocrText: ocrText, categoryName: selectedCategory.name)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            showAlert("Failed to save expense: \(error.localizedDescription)")
        }
    }

    /// Impara keyword dal testo OCR e le associa alla categoria scelta
    /// - Parameters:
    ///   - ocrText: Testo estratto dallo scontrino
    ///   - categoryName: Nome della categoria scelta dall'utente
    private func learnKeywordsFromReceipt(ocrText: String, categoryName: String) {
        // Estrai keyword significative
        let keywords = ReceiptOCRService.shared.extractMerchantKeywords(from: ocrText)

        guard !keywords.isEmpty else {
            print("📚 No keywords to learn from this receipt")
            return
        }

        print("🎓 Learning \(keywords.count) keywords for category '\(categoryName)'")

        for keyword in keywords {
            // Controlla se keyword già esiste
            if let existing = learnedKeywords.first(where: {
                $0.keyword == keyword && $0.categoryName == categoryName
            }) {
                // Keyword già presente: incrementa usage count
                existing.usageCount += 1
                existing.lastUsedDate = Date()
                print("   ↗️ Updated '\(keyword)' (now used \(existing.usageCount) times)")
            } else {
                // Keyword nuova: crea e salva
                let learned = LearnedKeyword(
                    categoryName: categoryName,
                    keyword: keyword,
                    learnedDate: Date(),
                    usageCount: 1,
                    lastUsedDate: Date()
                )
                modelContext.insert(learned)
                print("   ✨ Learned new keyword '\(keyword)' → \(categoryName)")
            }
        }

        print("✅ Learning complete! Total learned keywords: \(learnedKeywords.count)")
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
