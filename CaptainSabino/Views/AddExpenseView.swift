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

    // Prefilled data from OCR (optional)
    var prefilledAmount: Double?
    var prefilledCategory: Category?
    var prefilledDate: Date?
    var receiptImage: UIImage?
    var merchantName: String?

    @State private var amount = ""
    @State private var selectedCategory: Category?
    @State private var date = Date()
    @State private var notes = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
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
                    if categories.isEmpty {
                        Text("No categories available")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Category", selection: $selectedCategory) {
                            Text("Select...").tag(nil as Category?)
                            ForEach(categories) { category in
                                Label(category.name, systemImage: category.icon)
                                    .tag(category as Category?)
                            }
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
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }

                // Receipt Photo Section (if present)
                if receiptImage != nil {
                    Section("Receipt Photo") {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)

                            Text("Receipt photo attached")
                                .foregroundColor(.secondary)

                            Spacer()

                            Image(systemName: "photo")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
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
            receiptImagePath = ReceiptStorageService.shared.saveReceipt(
                image: receiptImage,
                date: date,
                amount: amountValue,
                categoryName: selectedCategory.name
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

        // MACHINE LEARNING: Learn keywords from merchant name
        if let merchantName = merchantName, !merchantName.isEmpty {
            learnKeywordsFromMerchant(merchantName: merchantName, categoryName: selectedCategory.name)
        }

        do {
            try modelContext.save()
            dismiss()
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

// MARK: - Preview

#Preview {
    AddExpenseView()
        .modelContainer(for: [Expense.self, Category.self])
}
