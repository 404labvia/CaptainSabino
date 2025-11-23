//
//  DashboardView.swift
//  YachtExpense
//
//  Dashboard principale con statistiche e grafico
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var settings: [YachtSettings]
    
    @State private var selectedMonth = Date()
    @State private var showingMonthPicker = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title and Month Selector on same line
                    titleWithMonthSelector

                    // Quick Actions (moved up)
                    quickActionsSection

                    // Chart
                    if !filteredExpenses.isEmpty {
                        chartSection
                    }

                    // Category Breakdown
                    categoryBreakdownSection
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Filtra spese per il mese selezionato
    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        return expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    /// Calcola totale spese del mese
    private var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    /// Raggruppa spese per categoria
    private var expensesByCategory: [(category: String, total: Double, color: Color, icon: String)] {
        let grouped = Dictionary(grouping: filteredExpenses) { $0.category?.name ?? "Unknown" }
        return grouped.map { key, values in
            let total = values.reduce(0) { $0 + $1.amount }
            let color = values.first?.category?.color ?? .gray
            let icon = values.first?.category?.icon ?? "questionmark.circle"
            return (category: key, total: total, color: color, icon: icon)
        }
        .sorted { $0.total > $1.total }
    }
    
    // MARK: - View Components

    private var titleWithMonthSelector: some View {
        HStack(alignment: .center) {
            // Dashboard Title
            Text("Capt. Sabino")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            // Month Selector (compact)
            HStack(spacing: 12) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }

                Text(selectedMonthText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(minWidth: 100)

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .disabled(isCurrentMonth)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .padding(.top, 10)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Expenses by Category")
                .font(.headline)

            ZStack {
                Chart(expensesByCategory, id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                }
                .frame(height: 250)

                // Total in the center
                VStack(spacing: 4) {
                    Text(String(format: "€%.2f", totalAmount))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("\(filteredExpenses.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Category")
                .font(.headline)

            ForEach(expensesByCategory, id: \.category) { item in
                HStack(spacing: 12) {
                    // Category Icon (like in ExpenseRowView)
                    ZStack {
                        Circle()
                            .fill(item.color.opacity(0.2))
                            .frame(width: 40, height: 40)

                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(item.color)
                    }

                    // Category Name
                    Text(item.category)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    // Percentage and Amount
                    HStack(spacing: 8) {
                        Text(String(format: "%.0f%%", (item.total / totalAmount) * 100))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 40, alignment: .trailing)

                        Text(String(format: "€%.2f", item.total))
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(minWidth: 80, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            // Add Expense Button
            NavigationLink {
                AddExpenseView()
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

            // Generate Report Button
            NavigationLink {
                ReportView(selectedMonth: selectedMonth)
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
        }
    }
    
    // MARK: - Methods
    
    private var selectedMonthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

// MARK: - Month Picker View

struct MonthPickerView: View {
    @Binding var selectedMonth: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Month")
                    .font(.headline)
                    .padding(.top)

                // Month/Year Picker
                DatePicker(
                    "",
                    selection: $selectedMonth,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_US"))

                Spacer()
            }
            .padding()
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .modelContainer(for: [Expense.self, Category.self, YachtSettings.self])
}
