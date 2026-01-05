//
//  ExpenseListView.swift
//  YachtExpense
//
//  Lista di tutte le spese con filtri
//

import SwiftUI
import SwiftData

struct ExpenseListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var categories: [Category]
    @Query private var settings: [YachtSettings]

    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var showingFilterSheet = false
    @State private var showingAddExpense = false
    @State private var showingGenerateSheet = false
    @State private var reportSelectedMonth = Calendar.current.component(.month, from: Date())
    @State private var reportSelectedYear = Calendar.current.component(.year, from: Date())
    @State private var isGenerating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("Expenses")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Quick Actions (Add Expense & Report)
                quickActionsSection
                    .padding(.horizontal)
                    .padding(.top, 10)

                // Content
                if filteredExpenses.isEmpty {
                    emptyStateView
                } else {
                    expenseListView
                }
            }
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "Search expenses...")
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterView(selectedCategory: $selectedCategory, categories: categories)
            }
            .sheet(isPresented: $showingGenerateSheet) {
                GenerateReportSheet(
                    selectedMonth: $reportSelectedMonth,
                    selectedYear: $reportSelectedYear,
                    isGenerating: $isGenerating,
                    onGenerate: {
                        generateReport()
                    },
                    onDismiss: {
                        showingGenerateSheet = false
                    },
                    expenseCount: reportExpenseCount,
                    totalAmount: reportTotalAmount
                )
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .overlay(alignment: .bottom) {
                if showingToast {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredExpenses: [Expense] {
        var result = expenses
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { expense in
                expense.notes.localizedCaseInsensitiveContains(searchText) ||
                expense.category?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
        
        // Filter by category
        if let selectedCategory = selectedCategory {
            result = result.filter { $0.category?.id == selectedCategory.id }
        }
        
        return result
    }
    
    // MARK: - View Components

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            // Add Expense Button
            Button {
                showingAddExpense = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Expense")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }

            // Report Button
            Button {
                showingGenerateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                    Text("Report")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .foregroundStyle(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }

            // Filter Button
            Button {
                showingFilterSheet = true
            } label: {
                Image(systemName: selectedCategory == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.blue)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }
        }
    }

    private var expenseListView: some View {
        List {
            ForEach(sortedDays, id: \.self) { day in
                Section(header: Text(dayHeaderText(for: day)).font(.headline)) {
                    ForEach(expensesGroupedByDay[day] ?? []) { expense in
                        NavigationLink {
                            EditExpenseView(expense: expense)
                        } label: {
                            ExpenseRowView(expense: expense)
                        }
                    }
                    .onDelete { indexSet in
                        deleteExpenses(at: indexSet, on: day)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 70))
                .foregroundStyle(.gray)
            
            Text("No Expenses Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to add your first expense")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                showingAddExpense.toggle()
            } label: {
                Label("Add Expense", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var expensesGroupedByDay: [Date: [Expense]] {
        Dictionary(grouping: filteredExpenses) { $0.dayKey }
    }

    private var sortedDays: [Date] {
        expensesGroupedByDay.keys.sorted(by: >)
    }

    // MARK: - Methods

    private func deleteExpenses(at offsets: IndexSet, on day: Date) {
        let expensesInSection = expensesGroupedByDay[day] ?? []
        for index in offsets {
            modelContext.delete(expensesInSection[index])
        }
    }

    private func dayHeaderText(for day: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expenseDay = calendar.startOfDay(for: day)

        if expenseDay == today {
            return "Today"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  expenseDay == yesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: day)
        }
    }

    // MARK: - Report Methods

    private var reportSelectedDate: Date {
        var components = DateComponents()
        components.year = reportSelectedYear
        components.month = reportSelectedMonth
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    private var reportExpenseCount: Int {
        let calendar = Calendar.current
        return expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: reportSelectedDate, toGranularity: .month)
        }.count
    }

    private var reportTotalAmount: Double {
        let calendar = Calendar.current
        return expenses
            .filter { calendar.isDate($0.date, equalTo: reportSelectedDate, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private func generateReport() {
        guard let yachtSettings = settings.first else {
            alertMessage = "Please configure yacht settings first"
            showingAlert = true
            return
        }

        isGenerating = true

        let calendar = Calendar.current
        let monthExpenses = expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: reportSelectedDate, toGranularity: .month)
        }

        do {
            let _ = try PDFService.shared.generateExpenseReport(
                expenses: monthExpenses,
                month: reportSelectedDate,
                settings: yachtSettings
            )
            showingGenerateSheet = false
            showToast("Report generated successfully")
        } catch {
            alertMessage = "Failed to generate report: \(error.localizedDescription)"
            showingAlert = true
        }

        isGenerating = false
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.3)) {
            showingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.3)) {
                showingToast = false
            }
        }
    }
}

// MARK: - Expense Row View

struct ExpenseRowView: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 15) {
            // Category Icon
            if let category = expense.category {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundStyle(category.color)
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.category?.name ?? "Unknown")
                    .font(.headline)
                
                if !expense.notes.isEmpty {
                    Text(expense.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(expense.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()

            // Entry Type Badge
            EntryTypeBadge(entryType: expense.entryType)

            // Amount
            Text(expense.formattedAmount)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Entry Type Badge

struct EntryTypeBadge: View {
    let entryType: EntryType

    var body: some View {
        Text(entryType.displayLetter)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(entryType.color)
            .frame(width: 20, height: 20)
    }
}

// MARK: - Filter View

struct FilterView: View {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedCategory = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("All Categories")
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                Section("Categories") {
                    ForEach(categories) { category in
                        Button {
                            selectedCategory = category
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                
                                Text(category.name)
                                
                                Spacer()
                                
                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExpenseListView()
        .modelContainer(for: [Expense.self, Category.self, YachtSettings.self])
}
