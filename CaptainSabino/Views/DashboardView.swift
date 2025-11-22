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
                    // Month Selector
                    monthSelectorSection
                    
                    // Total Card
                    totalExpenseCard
                    
                    // Chart
                    if !filteredExpenses.isEmpty {
                        chartSection
                    }
                    
                    // Category Breakdown
                    categoryBreakdownSection
                    
                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingMonthPicker.toggle()
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingMonthPicker) {
                MonthPickerView(selectedMonth: $selectedMonth)
            }
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
    private var expensesByCategory: [(category: String, total: Double, color: Color)] {
        let grouped = Dictionary(grouping: filteredExpenses) { $0.category?.name ?? "Unknown" }
        return grouped.map { key, values in
            let total = values.reduce(0) { $0 + $1.amount }
            let color = values.first?.category?.color ?? .gray
            return (category: key, total: total, color: color)
        }
        .sorted { $0.total > $1.total }
    }
    
    // MARK: - View Components
    
    private var monthSelectorSection: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            
            Spacer()
            
            Text(selectedMonthText)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .disabled(isCurrentMonth)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var totalExpenseCard: some View {
        VStack(spacing: 10) {
            Text("Total Expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(String(format: "€%.2f", totalAmount))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("\(filteredExpenses.count) transactions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(15)
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Expenses by Category")
                .font(.headline)
            
            Chart(expensesByCategory, id: \.category) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .annotation(position: .overlay) {
                    if item.total / totalAmount > 0.1 {
                        Text(String(format: "%.0f%%", (item.total / totalAmount) * 100))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 250)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Category Breakdown")
                .font(.headline)
            
            ForEach(expensesByCategory, id: \.category) { item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                    
                    Text(item.category)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "€%.2f", item.total))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(String(format: "%.1f%%", (item.total / totalAmount) * 100))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            NavigationLink {
                AddExpenseView()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Add New Expense")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            
            NavigationLink {
                ReportView(selectedMonth: selectedMonth)
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.title2)
                    Text("Generate Report")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .cornerRadius(12)
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
            DatePicker(
                "Select Month",
                selection: $selectedMonth,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
