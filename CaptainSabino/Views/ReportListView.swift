//
//  ReportListView.swift
//  CaptainSabino
//
//  Lista dei report PDF generati
//

import SwiftUI
import SwiftData
import QuickLook

struct ReportListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var settings: [YachtSettings]

    @State private var reports: [ReportInfo] = []
    @State private var showingGenerateSheet = false
    @State private var showingDeleteAlert = false
    @State private var reportToDelete: ReportInfo?
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isGenerating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var documentToShare: URL?
    @State private var showingShareSheet = false
    @State private var quickLookURL: URL?
    @State private var showingToast = false
    @State private var toastMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("Reports")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Quick Actions (Generate Report)
                quickActionsSection
                    .padding(.horizontal)
                    .padding(.top, 10)

                // Content
                if reports.isEmpty {
                    emptyStateView
                } else {
                    reportListView
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadReports()
            }
            .sheet(isPresented: $showingGenerateSheet) {
                GenerateReportSheet(
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    isGenerating: $isGenerating,
                    onGenerate: {
                        generateReport()
                    },
                    onDismiss: {
                        showingGenerateSheet = false
                    },
                    expenseCount: expenseCount(for: selectedDate),
                    totalAmount: totalAmount(for: selectedDate)
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = documentToShare {
                    ShareSheet(items: [url])
                }
            }
            .quickLookPreview($quickLookURL)
            .alert("Delete Report?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let report = reportToDelete {
                        deleteReport(report)
                    }
                }
            } message: {
                Text("This action cannot be undone.")
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

    // MARK: - View Components

    private var quickActionsSection: some View {
        Button {
            showingGenerateSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3)
                Text("Generate Report")
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

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Reports Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap Generate Report to create your first expense report")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    private var reportListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(reports) { report in
                    ReportCard(
                        report: report,
                        expenseCount: expenseCount(for: report.month),
                        totalAmount: totalAmount(for: report.month),
                        onCardTap: { viewReport(report) },
                        onDelete: {
                            reportToDelete = report
                            showingDeleteAlert = true
                        }
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Helper Properties

    private var selectedDate: Date {
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Helper Methods

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }

    private func loadReports() {
        reports = PDFService.shared.getSavedReports()
    }

    private func expenseCount(for month: Date) -> Int {
        let calendar = Calendar.current
        return expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: month, toGranularity: .month)
        }.count
    }

    private func totalAmount(for month: Date) -> Double {
        let calendar = Calendar.current
        return expenses
            .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
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
            calendar.isDate(expense.date, equalTo: selectedDate, toGranularity: .month)
        }

        do {
            let reportURL = try PDFService.shared.generateExpenseReport(
                expenses: monthExpenses,
                month: selectedDate,
                settings: yachtSettings
            )
            loadReports()
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

    private func viewReport(_ report: ReportInfo) {
        quickLookURL = report.url
    }

    private func shareReport(_ report: ReportInfo) {
        documentToShare = report.url
        showingShareSheet = true
    }

    private func regenerateReport(_ report: ReportInfo) {
        guard let yachtSettings = settings.first else {
            alertMessage = "Please configure yacht settings first"
            showingAlert = true
            return
        }

        let calendar = Calendar.current
        let monthExpenses = expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: report.month, toGranularity: .month)
        }

        do {
            let _ = try PDFService.shared.generateExpenseReport(
                expenses: monthExpenses,
                month: report.month,
                settings: yachtSettings
            )
            loadReports()
            showToast("Report regenerated successfully")
        } catch {
            alertMessage = "Failed to regenerate report: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func deleteReport(_ report: ReportInfo) {
        do {
            try PDFService.shared.deleteReport(at: report.url)
            loadReports()
        } catch {
            alertMessage = "Failed to delete report: \(error.localizedDescription)"
            showingAlert = true
        }
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

// MARK: - Generate Report Sheet

struct GenerateReportSheet: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    @Binding var isGenerating: Bool
    let onGenerate: () -> Void
    let onDismiss: () -> Void
    let expenseCount: Int
    let totalAmount: Double

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Select Month")
                    .font(.headline)
                    .padding(.top)

                // Month/Year Picker
                HStack(spacing: 0) {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthName(month)).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Year", selection: $selectedYear) {
                        ForEach((2020...2030), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                }
                .frame(height: 150)

                // Info about expenses
                VStack(spacing: 8) {
                    Text("\(expenseCount) expenses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(totalAmount.formattedCurrency)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                if expenseCount == 0 {
                    Text("No expenses for this month")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                // Generate Button
                Button {
                    onGenerate()
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .tint(Color.cream)
                        } else {
                            Image(systemName: "doc.badge.plus")
                        }
                        Text(isGenerating ? "Generating..." : "Generate PDF")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.cream)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(expenseCount > 0 ? Color.forestGreen : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(expenseCount == 0 || isGenerating)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("New Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Report Card

struct ReportCard: View {
    let report: ReportInfo
    let expenseCount: Int
    let totalAmount: Double
    let onCardTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onCardTap()
        } label: {
            HStack(spacing: 16) {
                // PDF Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 50, height: 60)

                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.formattedMonth)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(expenseCount) expenses • \(totalAmount.formattedCurrency)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Actions Menu (solo Delete)
                Menu {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ReportListView()
        .modelContainer(for: [Expense.self, YachtSettings.self])
}
