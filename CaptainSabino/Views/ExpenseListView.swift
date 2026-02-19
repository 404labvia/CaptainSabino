//
//  ExpenseListView.swift
//  YachtExpense
//
//  Lista di tutte le spese con filtri
//

import SwiftUI
import SwiftData
import QuickLook

struct ExpenseListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var categories: [Category]
    @Query private var settings: [YachtSettings]

    @State private var searchText = ""
    @State private var customDateFrom: Date? = nil
    @State private var customDateTo: Date? = nil
    @State private var showingDateSheet = false
    @State private var showingAddExpense = false
    @State private var showingGenerateSheet = false
    @State private var reportSelectedMonth = Calendar.current.component(.month, from: Date())
    @State private var reportSelectedYear = Calendar.current.component(.year, from: Date())
    @State private var isGenerating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var quickLookURL: URL?
    @State private var selectedReceiptExpense: Expense?

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

                // Search bar + date filter chips
                searchAndFilterSection
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Content
                if filteredExpenses.isEmpty {
                    emptyStateView
                } else {
                    expenseListView
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
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
            .sheet(item: $selectedReceiptExpense) { expense in
                ReceiptImageViewer(expense: expense)
            }
            .sheet(isPresented: $showingDateSheet) {
                DateFilterSheet(
                    customDateFrom: $customDateFrom,
                    customDateTo: $customDateTo,
                    onApply: { showingDateSheet = false },
                    onReset: {
                        customDateFrom = nil
                        customDateTo = nil
                        showingDateSheet = false
                    }
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
            .quickLookPreview($quickLookURL)
        }
    }

    // MARK: - Computed Properties

    private var filteredExpenses: [Expense] {
        var result = expenses

        // Filtro testo: merchant + categoria
        if !searchText.isEmpty {
            result = result.filter { expense in
                expense.merchantName.localizedCaseInsensitiveContains(searchText) ||
                expense.category?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        // Filtro data: singola giornata (customDateTo == nil) o range (customDateTo != nil)
        if let from = customDateFrom {
            let cal = Calendar.current
            let startOfFrom = cal.startOfDay(for: from)
            if let to = customDateTo {
                result = result.filter { $0.date >= startOfFrom && $0.date < to }
            } else {
                let nextDay = cal.date(byAdding: .day, value: 1, to: startOfFrom)!
                result = result.filter { $0.date >= startOfFrom && $0.date < nextDay }
            }
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
                .background(Color.navy)
                .foregroundStyle(Color.cream)
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
                .background(Color.forestGreen)
                .foregroundStyle(Color.cream)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }
        }
    }

    private var searchAndFilterSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("Search merchant or category...", text: $searchText)
                .font(.subheadline)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // Bottone calendario → apre DateFilterSheet; diventa blu quando filtro attivo
            Button {
                showingDateSheet = true
            } label: {
                Image(systemName: customDateFrom != nil ? "calendar.badge.checkmark" : "calendar")
                    .font(.subheadline)
                    .foregroundStyle(customDateFrom != nil ? Color.royalBlue : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private var expenseListView: some View {
        List {
            ForEach(sortedDays, id: \.self) { day in
                Section(header: Text(dayHeaderText(for: day)).font(.headline)) {
                    ForEach(expensesGroupedByDay[day] ?? []) { expense in
                        NavigationLink {
                            EditExpenseView(expense: expense)
                        } label: {
                            ExpenseRowView(expense: expense) {
                                selectedReceiptExpense = expense
                            }
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

            Text(searchText.isEmpty && customDateFrom == nil ? "No Expenses Yet" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty && customDateFrom == nil
                 ? "Tap + to add your first expense"
                 : "Try a different search or filter")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if searchText.isEmpty && customDateFrom == nil {
                Button {
                    showingAddExpense.toggle()
                } label: {
                    Label("Add Expense", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .background(Color.navy)
                        .foregroundStyle(Color.cream)
                        .cornerRadius(12)
                }
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
            let expense = expensesInSection[index]
            // Elimina immagine associata se presente
            if let path = expense.receiptImagePath {
                ImageStorageService.shared.deleteImage(filename: path, entryType: expense.entryType)
            }
            modelContext.delete(expense)
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
            let reportURL = try PDFService.shared.generateExpenseReport(
                expenses: monthExpenses,
                month: reportSelectedDate,
                settings: yachtSettings
            )
            showingGenerateSheet = false
            // Apri direttamente il PDF con QuickLook
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                quickLookURL = reportURL
            }
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
    var onReceiptTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Category Icon
            if let category = expense.category {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: category.icon)
                        .font(.footnote)
                        .foregroundStyle(category.color)
                }
            }

            // Details
            VStack(alignment: .leading, spacing: 3) {
                // Riga 1: merchant name (o categoria se merchant vuoto)
                Text(expense.merchantName.isEmpty ? (expense.category?.name ?? "Unknown") : expense.merchantName)
                    .font(.headline)
                    .lineLimit(1)

                // Riga 2: categoria
                if let categoryName = expense.category?.name {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Icona camera/scontrino (solo se immagine disponibile)
            if let path = expense.receiptImagePath,
               ImageStorageService.shared.loadImage(filename: path, entryType: expense.entryType) != nil {
                Button {
                    onReceiptTap?()
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Entry Type Badge
            EntryTypeBadge(entryType: expense.entryType)

            // Amount
            Text(expense.formattedAmount)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(minWidth: 80, alignment: .trailing)
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

// MARK: - Receipt Image Viewer

struct ReceiptImageViewer: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss

    @State private var zoomScale: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @GestureState private var dragState: CGSize = .zero

    private var image: UIImage? {
        guard let path = expense.receiptImagePath else { return nil }
        return ImageStorageService.shared.loadImage(filename: path, entryType: expense.entryType)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(zoomScale * magnifyBy)
                            .offset(
                                x: dragOffset.width + dragState.width,
                                y: dragOffset.height + dragState.height
                            )
                            .gesture(
                                MagnificationGesture()
                                    .updating($magnifyBy) { value, state, _ in state = value }
                                    .onEnded { value in
                                        zoomScale = max(1.0, min(zoomScale * value, 5.0))
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .updating($dragState) { value, state, _ in
                                        state = value.translation
                                    }
                                    .onEnded { value in
                                        if zoomScale > 1.0 {
                                            dragOffset.width += value.translation.width
                                            dragOffset.height += value.translation.height
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3)) {
                                    zoomScale = 1.0
                                    dragOffset = .zero
                                }
                            }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .background(Color.black)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Image not available")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(expense.merchantName.isEmpty ? (expense.category?.name ?? "Receipt") : expense.merchantName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.navy)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Date Filter Sheet

struct DateFilterSheet: View {
    @Binding var customDateFrom: Date?
    @Binding var customDateTo: Date?
    let onApply: () -> Void
    let onReset: () -> Void

    @State private var isRangeMode: Bool = false
    @State private var singleDate: Date = Date()
    @State private var fromDate: Date = Date()
    @State private var toDate: Date = Date()
    @State private var rangeStep: Int = 0   // 0 = scegli FROM, 1 = scegli TO
    @State private var didAppear = false    // guard onChange durante il ripristino iniziale

    private var shortFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toggle Single / Range
                Picker("", selection: $isRangeMode) {
                    Text("Single date").tag(false)
                    Text("Custom range").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .onChange(of: isRangeMode) { _, _ in
                    rangeStep = 0
                }

                Divider()

                if !isRangeMode {
                    // SINGLE DATE: tap data → applica e chiude
                    DatePicker("", selection: $singleDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal, 8)
                        .onChange(of: singleDate) { _, newDate in
                            guard didAppear else { return }
                            let cal = Calendar.current
                            customDateFrom = cal.startOfDay(for: newDate)
                            customDateTo = nil   // nil = singola giornata
                            onApply()
                        }
                } else {
                    // RANGE: step 0 = scegli FROM, step 1 = scegli TO
                    HStack(spacing: 6) {
                        if rangeStep == 0 {
                            Image(systemName: "1.circle.fill")
                                .foregroundStyle(Color.royalBlue)
                            Text("Select start date")
                                .foregroundStyle(Color.royalBlue)
                        } else {
                            Image(systemName: "2.circle.fill")
                                .foregroundStyle(Color.royalBlue)
                            Text("From \(shortFormatter.string(from: fromDate)) → select end date")
                                .foregroundStyle(Color.royalBlue)
                        }
                        Spacer()
                        if rangeStep == 1 {
                            Button("Restart") { rangeStep = 0 }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Mostra picker diverso in base allo step, così onChange è sempre fresco
                    if rangeStep == 0 {
                        DatePicker("", selection: $fromDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal, 8)
                            .onChange(of: fromDate) { _, _ in
                                guard didAppear else { return }
                                toDate = fromDate
                                withAnimation(.easeInOut(duration: 0.15)) { rangeStep = 1 }
                            }
                    } else {
                        DatePicker("", selection: $toDate, in: fromDate..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal, 8)
                            .onChange(of: toDate) { _, newDate in
                                guard didAppear else { return }
                                let cal = Calendar.current
                                customDateFrom = cal.startOfDay(for: fromDate)
                                customDateTo = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: newDate))
                                onApply()
                            }
                    }
                }

                Spacer()
            }
            .navigationTitle("Date Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { onReset() }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if let from = customDateFrom {
                    singleDate = from
                    fromDate = from
                    if let to = customDateTo {
                        // Ripristina range: to è "exclusive", risaliamo al giorno precedente
                        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: to) ?? from
                        toDate = lastDay
                        isRangeMode = true
                        rangeStep = 0   // l'utente riparte a scegliere FROM
                    }
                }
                // Attiva il flag DOPO il primo render così onChange non scatta durante il ripristino
                DispatchQueue.main.async { didAppear = true }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Preview

#Preview {
    ExpenseListView()
        .modelContainer(for: [Expense.self, Category.self, YachtSettings.self])
}
