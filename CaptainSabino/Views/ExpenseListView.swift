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
    
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var showingFilterSheet = false
    @State private var showingAddExpense = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if filteredExpenses.isEmpty {
                    emptyStateView
                } else {
                    expenseListView
                }
            }
            .navigationTitle("Expenses")
            .searchable(text: $searchText, prompt: "Search expenses...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFilterSheet.toggle()
                    } label: {
                        Image(systemName: selectedCategory == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddExpense.toggle()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterView(selectedCategory: $selectedCategory, categories: categories)
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
    
    private var expenseListView: some View {
        List {
            ForEach(groupedExpenses.keys.sorted(by: >), id: \.self) { monthYear in
                Section(header: Text(monthYear).font(.headline)) {
                    ForEach(groupedExpenses[monthYear] ?? []) { expense in
                        NavigationLink {
                            EditExpenseView(expense: expense)
                        } label: {
                            ExpenseRowView(expense: expense)
                        }
                    }
                    .onDelete { indexSet in
                        deleteExpenses(at: indexSet, in: monthYear)
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
    
    private var groupedExpenses: [String: [Expense]] {
        Dictionary(grouping: filteredExpenses) { $0.monthYear }
    }
    
    // MARK: - Methods
    
    private func deleteExpenses(at offsets: IndexSet, in monthYear: String) {
        let expensesInSection = groupedExpenses[monthYear] ?? []
        for index in offsets {
            modelContext.delete(expensesInSection[index])
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
            
            // Amount
            Text(expense.formattedAmount)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
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
        .modelContainer(for: [Expense.self, Category.self])
}
