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
        VStack(alignment: .leading, spacing: 6) {
            // Search bar
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

            // Chip dinamica: visibile solo quando filtro data attivo
            if customDateFrom != nil {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(Color.royalBlue)
                    Text(filterChipText)
                        .font(.caption)
                        .fontWeight(.medium)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            customDateFrom = nil
                            customDateTo = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .scale(scale: 0.85).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: customDateFrom != nil)
    }

    private var filterChipText: String {
        guard let from = customDateFrom else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        if let to = customDateTo {
            let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: to) ?? from
            return "\(f.string(from: from)) – \(f.string(from: lastDay))"
        }
        return f.string(from: from)
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

    private var hasReceipt: Bool {
        guard let path = expense.receiptImagePath else { return false }
        return ImageStorageService.shared.loadImage(filename: path, entryType: expense.entryType) != nil
    }

    var body: some View {
        // Layout: [Icon 36] [Merchant+Cat ∞] [Amount min70] [TechCol 20]
        // La VStack merchant prende tutto lo spazio residuo → tronca solo se necessario
        HStack(spacing: 10) {
            // Icona categoria (larghezza fissa 36)
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

            // Merchant + categoria — occupa tutto lo spazio disponibile
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchantName.isEmpty ? (expense.category?.name ?? "Unknown") : expense.merchantName)
                    .font(.headline)
                    .lineLimit(1)
                if let categoryName = expense.category?.name {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Importo (larghezza minima fissa)
            Text(expense.formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(minWidth: 70, alignment: .trailing)

            // Colonna tecnica: tipo (C/R/I) + camera impilati verticalmente
            VStack(spacing: 3) {
                EntryTypeBadge(entryType: expense.entryType)
                if hasReceipt {
                    Button {
                        onReceiptTap?()
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 20)
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

    private var image: UIImage? {
        guard let path = expense.receiptImagePath else { return nil }
        return ImageStorageService.shared.loadImage(filename: path, entryType: expense.entryType)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ZoomableScrollView(image: image)
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
                    Button { dismiss() } label: {
                        Text("Close")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.navy)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Zoomable Scroll View (UIScrollView nativo)

struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black
        // Evita che UIKit aggiusti il contentInset per la safe area, che causa schermo nero
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView,
              scrollView.bounds != .zero else { return }
        // Aggiorna frame solo se non ancora impostato o se i bounds cambiano (es. rotazione)
        guard imageView.frame.size != scrollView.bounds.size else { return }
        scrollView.setZoomScale(1.0, animated: false)
        imageView.frame = scrollView.bounds
        scrollView.contentSize = scrollView.bounds.size
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView else { return }
            // Centra l'immagine quando è più piccola del frame dello scroll view
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width / 2 + offsetX,
                y: scrollView.contentSize.height / 2 + offsetY
            )
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > 1.0 {
                // Zoom out al minimo
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                // Zoom in centrato sul punto toccato
                let point = gesture.location(in: imageView)
                let zoomRect = CGRect(
                    x: point.x - 50,
                    y: point.y - 50,
                    width: 100,
                    height: 100
                )
                scrollView.zoom(to: zoomRect, animated: true)
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
