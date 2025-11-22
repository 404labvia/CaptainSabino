//
//  ReportView.swift
//  YachtExpense
//
//  Generazione e invio report PDF
//

import SwiftUI
import SwiftData

struct ReportView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var settings: [YachtSettings]

    @State private var selectedMonth: Date
    @State private var showingMonthPicker = false

    @State private var isGenerating = false
    @State private var generatedPDFURL: URL?
    @State private var showingShareSheet = false
    @State private var showingMailView = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    // MARK: - Initializer

    init(selectedMonth: Date = Date()) {
        _selectedMonth = State(initialValue: selectedMonth)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                headerSection
                
                // Preview
                previewSection
                
                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Generate Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = generatedPDFURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingMailView) {
            if let url = generatedPDFURL,
               let currentSettings = settings.first {
                MailView(
                    pdfURL: url,
                    recipientEmail: currentSettings.ownerEmail,
                    subject: "Expense Report - \(monthText)",
                    yachtName: currentSettings.yachtName
                )
            } else {
                // Fallback to prevent nil view (should never happen due to sendEmail() checks)
                EmptyView()
            }
        }
        .alert(isGenerating ? "Generating..." : "Error", isPresented: .constant(isGenerating || showingAlert)) {
            if !isGenerating {
                Button("OK") { showingAlert = false }
            }
        } message: {
            if isGenerating {
                Text("Please wait...")
            } else {
                Text(alertMessage)
            }
        }
        .sheet(isPresented: $showingMonthPicker) {
            MonthPickerView(selectedMonth: $selectedMonth)
        }
    }
    
    // MARK: - Computed Properties
    
    private var monthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        return expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }
    
    private var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private var expensesByCategory: [(category: String, total: Double)] {
        let grouped = Dictionary(grouping: filteredExpenses) { $0.category?.name ?? "Unknown" }
        return grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Expense Report")
                .font(.title)
                .fontWeight(.bold)

            // Month selector button
            Button {
                showingMonthPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                    Text(monthText)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Report Summary")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Period")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(monthText)
                        .fontWeight(.medium)
                }
                
                Divider()
                
                HStack {
                    Text("Total Expenses")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "€%.2f", totalAmount))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Divider()
                
                HStack {
                    Text("Transactions")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(filteredExpenses.count)")
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Category Breakdown
            VStack(alignment: .leading, spacing: 10) {
                Text("By Category")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ForEach(expensesByCategory, id: \.category) { item in
                    HStack {
                        Text(item.category)
                        Spacer()
                        Text(String(format: "€%.2f", item.total))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                generatePDF()
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Generate PDF")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isGenerating)
            
            if generatedPDFURL != nil {
                HStack(spacing: 12) {
                    Button {
                        sendEmail()
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Send Email")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func generatePDF() {
        guard let settings = settings.first else {
            showAlert("Settings not configured")
            return
        }
        
        isGenerating = true
        
        Task {
            do {
                let pdfURL = try PDFService.shared.generateExpenseReport(
                    expenses: filteredExpenses,
                    month: selectedMonth,
                    settings: settings
                )

                await MainActor.run {
                    self.generatedPDFURL = pdfURL
                    self.isGenerating = false

                    // Small delay to ensure PDF is ready, then auto-show share sheet
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        await MainActor.run {
                            self.showingShareSheet = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.showAlert("Failed to generate PDF: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func sendEmail() {
        // Check if device can send email
        guard EmailService.shared.canSendEmail() else {
            showAlert("This device is not configured to send email. Please set up Mail app first.")
            return
        }

        // Check if we have all required data
        guard generatedPDFURL != nil else {
            showAlert("Please generate a PDF first")
            return
        }

        guard settings.first != nil else {
            showAlert("Settings not configured")
            return
        }

        // All checks passed, show mail view
        showingMailView = true
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Share Sheet (UIKit Bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReportView(selectedMonth: Date())
            .modelContainer(for: [Expense.self, YachtSettings.self])
    }
}
