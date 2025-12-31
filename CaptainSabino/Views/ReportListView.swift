//
//  ReportListView.swift
//  CaptainSabino
//
//  Lista dei report PDF generati
//

import SwiftUI
import SwiftData

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if reports.isEmpty {
                    emptyStateView
                } else {
                    reportListView
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGenerateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadReports()
            }
            .sheet(isPresented: $showingGenerateSheet) {
                generateReportSheet
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = documentToShare {
                    ShareSheet(items: [url])
                }
            }
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
        }
    }

    // MARK: - View Components

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Reports Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to generate your first expense report")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var reportListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(reports) { report in
                    ReportCard(
                        report: report,
                        expenseCount: expenseCount(for: report.month),
                        totalAmount: totalAmount(for: report.month),
                        onView: { viewReport(report) },
                        onShare: { shareReport(report) },
                        onRegenerate: { regenerateReport(report) },
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

    private var generateReportSheet: some View {
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
                let count = expenseCount(for: selectedDate)
                let total = totalAmount(for: selectedDate)

                VStack(spacing: 8) {
                    Text("\(count) expenses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(format: "€%.2f", total))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                if count == 0 {
                    Text("No expenses for this month")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                // Generate Button
                Button {
                    generateReport()
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "doc.badge.plus")
                        }
                        Text(isGenerating ? "Generating..." : "Generate Report")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(count > 0 ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(count == 0 || isGenerating)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("New Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingGenerateSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
            let _ = try PDFService.shared.generateExpenseReport(
                expenses: monthExpenses,
                month: selectedDate,
                settings: yachtSettings
            )
            loadReports()
            showingGenerateSheet = false
        } catch {
            alertMessage = "Failed to generate report: \(error.localizedDescription)"
            showingAlert = true
        }

        isGenerating = false
    }

    private func viewReport(_ report: ReportInfo) {
        documentToShare = report.url
        showingShareSheet = true
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
}

// MARK: - Report Card

struct ReportCard: View {
    let report: ReportInfo
    let expenseCount: Int
    let totalAmount: Double
    let onView: () -> Void
    let onShare: () -> Void
    let onRegenerate: () -> Void
    let onDelete: () -> Void

    var body: some View {
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

                Text("\(expenseCount) expenses • \(String(format: "€%.2f", totalAmount))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions Menu
            Menu {
                Button {
                    onView()
                } label: {
                    Label("View", systemImage: "eye")
                }

                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }

                Divider()

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
}

// MARK: - Preview

#Preview {
    ReportListView()
        .modelContainer(for: [Expense.self, YachtSettings.self])
}
