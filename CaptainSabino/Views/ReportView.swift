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
                // Month Picker
                monthPickerSection

                // Generate PDF Button
                generatePDFButton

                // Send Button (appears after PDF generation)
                if generatedPDFURL != nil {
                    sendButton
                }

                // Preview
                previewSection
            }
            .padding()
        }
        .navigationTitle("Generate Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMailView) {
            if let url = generatedPDFURL,
               let yachtSettings = settings.first {
                MailView(
                    pdfURL: url,
                    recipientEmail: yachtSettings.ownerEmail,
                    subject: "Expense Report - \(monthText)",
                    yachtName: yachtSettings.yachtName,
                    captainName: yachtSettings.captainName
                )
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

    private var monthPickerSection: some View {
        VStack(spacing: 12) {
            Text("Select Month")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showingMonthPicker = true
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title3)
                    Text(monthText)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.subheadline)
                }
                .foregroundStyle(.primary)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var generatePDFButton: some View {
        Button {
            generatePDF()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3)
                Text("Generate PDF")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .disabled(isGenerating)
    }

    private var sendButton: some View {
        Button {
            sendEmail()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                Text("Send")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.green)
            .foregroundStyle(.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
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
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
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
        guard let settings = settings.first else {
            showAlert("Settings not configured")
            return
        }

        guard !settings.ownerEmail.isEmpty else {
            showAlert("Owner email not configured in Settings")
            return
        }

        guard EmailService.shared.canSendEmail() else {
            showAlert("Mail services are not available on this device. Please configure the Mail app.")
            return
        }

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
