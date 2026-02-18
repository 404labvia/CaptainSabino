//
//  AddEditCategoryView.swift
//  CaptainSabino
//
//  Form per creare o modificare una categoria custom
//

import SwiftUI
import SwiftData

// MARK: - Icone SF Symbol curate per categorie

private let curatedIcons: [(section: String, icons: [String])] = [
    ("Food & Drinks", ["fork.knife", "cup.and.saucer", "wineglass", "cart", "basket"]),
    ("Transport", ["car.fill", "airplane", "fuelpump", "fuelpump.fill", "ferry"]),
    ("Marine", ["sailboat", "anchor", "lifepreserver", "water.waves", "helm"]),
    ("Shopping", ["bag", "handbag", "shippingbox", "giftcard.fill", "tag"]),
    ("Health", ["cross.case", "pills", "stethoscope", "heart.fill", "bandage"]),
    ("Services", ["wrench.and.screwdriver", "hammer", "washer", "bolt", "gear"]),
    ("People", ["person.3", "figure.walk", "person.badge.key", "person.crop.circle", "person.2"]),
    ("Finance", ["banknote", "creditcard", "receipt", "dollarsign.circle", "chart.bar"]),
    ("Other", ["star", "bell", "flag", "house", "questionmark.circle"])
]

struct AddEditCategoryView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingCategory: Category?
    let allCategories: [Category]

    @State private var name = ""
    @State private var selectedColor = Color.blue
    @State private var selectedIcon = "tag"
    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var isEditing: Bool { existingCategory != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Nome categoria
                Section("Name") {
                    TextField("Category name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                // Anteprima
                Section("Preview") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(selectedColor.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: selectedIcon)
                                .font(.title3)
                                .foregroundStyle(selectedColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Category Name" : name)
                                .font(.headline)
                                .foregroundStyle(name.isEmpty ? .secondary : .primary)
                            Text("Custom")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Colore
                Section("Color") {
                    ColorPicker("Select color", selection: $selectedColor, supportsOpacity: false)
                }

                // Icona
                Section("Icon") {
                    iconPickerGrid
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.navy)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveCategory() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.premiumYellow)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadExistingData()
            }
        }
    }

    // MARK: - Icon Picker Grid

    private var iconPickerGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(curatedIcons, id: \.section) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.section)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(group.icons, id: \.self) { icon in
                            iconCell(icon)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func iconCell(_ icon: String) -> some View {
        let isSelected = selectedIcon == icon
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedIcon = icon
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? selectedColor.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? selectedColor : Color.clear, lineWidth: 2)
                    )

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? selectedColor : .secondary)
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Methods

    private func loadExistingData() {
        guard let category = existingCategory else { return }
        name = category.name
        selectedColor = category.color
        selectedIcon = category.icon
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            alertMessage = "Please enter a category name."
            showingAlert = true
            return
        }

        // Verifica duplicati (escludendo la categoria corrente in edit)
        let isDuplicate = allCategories.contains { cat in
            cat.name.lowercased() == trimmedName.lowercased() &&
            cat.id != existingCategory?.id
        }

        guard !isDuplicate else {
            alertMessage = "A category named \"\(trimmedName)\" already exists."
            showingAlert = true
            return
        }

        let hexColor = selectedColor.toHex()

        if let category = existingCategory {
            // Edit
            category.name = trimmedName
            category.colorHex = hexColor
            category.icon = selectedIcon
        } else {
            // Create
            let newCategory = Category(
                name: trimmedName,
                icon: selectedIcon,
                color: hexColor,
                isPredefined: false
            )
            modelContext.insert(newCategory)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Color → HEX Extension

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Preview

#Preview {
    AddEditCategoryView(existingCategory: nil, allCategories: [])
        .modelContainer(for: [Category.self])
}
