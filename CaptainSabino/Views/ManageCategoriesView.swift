//
//  ManageCategoriesView.swift
//  CaptainSabino
//
//  Gestione categorie: visualizza predefinite + CRUD per categorie custom
//

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
                                categoryToDelete = category
                                showingDeleteConfirmation = true
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

            // Sezione categorie predefinite (solo lettura)
            Section("Predefined Categories (\(predefinedCategories.count))") {
                ForEach(predefinedCategories) { category in
                    CategoryManageRow(category: category)
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

    private var deleteDialogTitle: String {
        guard let cat = categoryToDelete else { return "Delete Category?" }
        let count = cat.expenses?.count ?? 0
        if count > 0 {
            return "Category has \(count) expense\(count == 1 ? "" : "s")"
        }
        return "Delete \"\(cat.name)\"?"
    }

    private var deleteDialogMessage: String {
        guard let cat = categoryToDelete else { return "" }
        let count = cat.expenses?.count ?? 0
        if count > 0 {
            return "The category will be removed from the list but the \(count) associated expense\(count == 1 ? "" : "s") will not be deleted."
        }
        return "This action cannot be undone."
    }

    private func deleteCategory(_ category: Category) {
        let expenseCount = category.expenses?.count ?? 0
        if expenseCount > 0 {
            // Soft delete: rimuovi solo dalla lista predefinite/custom, non eliminare
            // Le spese mantengono il riferimento alla categoria ma non è più visibile in selezione
            // Marchiamo come non predefinita e usiamo un nome oscurato per nasconderla
            // In realtà il nullify di SwiftData gestisce automaticamente la relazione
            modelContext.delete(category)
        } else {
            modelContext.delete(category)
        }
        try? modelContext.save()
        categoryToDelete = nil
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
