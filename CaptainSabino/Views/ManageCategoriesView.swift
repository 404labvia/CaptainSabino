//
//  ManageCategoriesView.swift
//  CaptainSabino
//
//  Gestione categorie: visualizza predefinite + CRUD per categorie custom + delete predefinite

import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var showingAddCategory = false
    @State private var categoryToEdit: Category?
    @State private var categoryToDelete: Category?
    @State private var showingDeleteConfirmation = false
    @State private var showingMoveSheet = false

    // MARK: - Computed Properties

    private var customCategories: [Category] {
        categories.filter { !$0.isPredefined }
    }

    private var predefinedCategories: [Category] {
        categories.filter { $0.isPredefined }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Sezione categorie custom
            Section {
                ForEach(customCategories) { category in
                    CategoryManageRow(category: category)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                requestDelete(category)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                categoryToEdit = category
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.royalBlue)
                        }
                }

                // Bottone aggiungi
                Button {
                    showingAddCategory = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.navy.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "plus")
                                .font(.footnote)
                                .foregroundStyle(Color.navy)
                        }
                        Text("Add Category")
                            .foregroundStyle(Color.navy)
                            .fontWeight(.medium)
                    }
                }
            } header: {
                Text("Custom Categories (\(customCategories.count))")
            } footer: {
                if customCategories.isEmpty {
                    Text("Tap \"Add Category\" to create your first custom category.")
                }
            }

            // Sezione categorie predefinite (delete abilitato)
            Section("Predefined Categories (\(predefinedCategories.count))") {
                ForEach(predefinedCategories) { category in
                    CategoryManageRow(category: category)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                requestDelete(category)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCategory) {
            AddEditCategoryView(existingCategory: nil, allCategories: categories)
        }
        .sheet(item: $categoryToEdit) { category in
            AddEditCategoryView(existingCategory: category, allCategories: categories)
        }
        .sheet(isPresented: $showingMoveSheet) {
            if let cat = categoryToDelete {
                MoveCategoryExpensesSheet(
                    categoryToDelete: cat,
                    availableCategories: categories.filter { $0.id != cat.id },
                    onMoveAndDelete: { target in
                        moveAndDeleteCategory(cat, to: target)
                        showingMoveSheet = false
                    },
                    onDeleteOnly: {
                        deleteCategory(cat)
                        showingMoveSheet = false
                    },
                    onCancel: {
                        categoryToDelete = nil
                        showingMoveSheet = false
                    }
                )
            }
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let cat = categoryToDelete {
                Button("Delete \"\(cat.name)\"", role: .destructive) {
                    deleteCategory(cat)
                }
            }
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
        } message: {
            Text(deleteDialogMessage)
        }
    }

    // MARK: - Helpers

    /// Decide se mostrare il confirmation dialog (nessuna spesa) o lo sheet move-expenses
    private func requestDelete(_ category: Category) {
        categoryToDelete = category
        let count = category.expenses?.count ?? 0
        if count > 0 {
            showingMoveSheet = true
        } else {
            showingDeleteConfirmation = true
        }
    }

    private var deleteDialogTitle: String {
        guard let cat = categoryToDelete else { return "Delete Category?" }
        return "Delete \"\(cat.name)\"?"
    }

    private var deleteDialogMessage: String {
        return "This action cannot be undone."
    }

    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        try? modelContext.save()
        categoryToDelete = nil
    }

    private func moveAndDeleteCategory(_ category: Category, to target: Category) {
        if let expenses = category.expenses {
            for expense in expenses {
                expense.category = target
            }
        }
        modelContext.delete(category)
        try? modelContext.save()
        categoryToDelete = nil
    }
}

// MARK: - Move Category Expenses Sheet

struct MoveCategoryExpensesSheet: View {
    let categoryToDelete: Category
    let availableCategories: [Category]
    let onMoveAndDelete: (Category) -> Void
    let onDeleteOnly: () -> Void
    let onCancel: () -> Void

    @State private var selectedTarget: Category?

    var expenseCount: Int { categoryToDelete.expenses?.count ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\"\(categoryToDelete.name)\" has \(expenseCount) expense\(expenseCount == 1 ? "" : "s"). Select a category to reassign them to, or delete without reassigning.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Section("Move expenses to:") {
                    ForEach(availableCategories) { cat in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(cat.color.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Image(systemName: cat.icon)
                                    .font(.caption)
                                    .foregroundStyle(cat.color)
                            }
                            Text(cat.name)
                            Spacer()
                            if selectedTarget?.id == cat.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.navy)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTarget = cat }
                    }
                }

                Section {
                    Button("Delete without reassigning", role: .destructive) {
                        onDeleteOnly()
                    }
                } footer: {
                    Text("Expenses will appear as \"Unknown\" category.")
                        .font(.caption)
                }
            }
            .navigationTitle("Delete Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Move & Delete") {
                        if let target = selectedTarget { onMoveAndDelete(target) }
                    }
                    .foregroundStyle(selectedTarget != nil ? Color.navy : .secondary)
                    .fontWeight(.semibold)
                    .disabled(selectedTarget == nil)
                }
            }
            .onAppear {
                selectedTarget = availableCategories.first
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Category Row

struct CategoryManageRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            // Icona categoria
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: category.icon)
                    .font(.footnote)
                    .foregroundStyle(category.color)
            }

            // Nome
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                if category.isPredefined {
                    Text("Predefined")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Badge numero spese
            let count = category.expenses?.count ?? 0
            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ManageCategoriesView()
            .modelContainer(for: [Category.self, Expense.self])
    }
}
