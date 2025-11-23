//
//  PDFService.swift
//  YachtExpense
//
//  Servizio per generazione PDF con UIGraphicsPDFRenderer
//

import Foundation
import UIKit

class PDFService {
    // MARK: - Singleton
    
    static let shared = PDFService()
    private init() {}
    
    // MARK: - PDF Generation
    
    /// Genera PDF del report spese
    /// - Parameters:
    ///   - expenses: Array di spese da includere
    ///   - month: Mese di riferimento
    ///   - settings: Impostazioni yacht
    /// - Returns: URL del PDF generato
    func generateExpenseReport(
        expenses: [Expense],
        month: Date,
        settings: YachtSettings
    ) throws -> URL {
        // Crea il formato PDF
        let pageSize = CGSize(width: 595.28, height: 841.89) // A4 in punti (72 DPI)
        let pageRect = CGRect(origin: .zero, size: pageSize)
        
        // Crea il renderer
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        // Genera il PDF
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 40

            // Header
            yPosition = drawHeader(rect: pageRect, yPosition: yPosition, settings: settings, month: month)
            
            yPosition += 20

            // Summary
            yPosition = drawSummary(rect: pageRect, yPosition: yPosition, expenses: expenses)
            
            yPosition += 30

            // Summary Table
            yPosition = drawExpenseTable(in: context, rect: pageRect, yPosition: yPosition, expenses: expenses)

            yPosition += 40

            // Detailed Table
            drawDetailedExpenseTable(in: context, rect: pageRect, yPosition: yPosition, expenses: expenses, month: month)
        }
        
        // Salva il PDF
        let fileName = "ExpenseReport_\(formatDateForFileName(month)).pdf"
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "PDFService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
        }
        let pdfURL = documentsPath.appendingPathComponent(fileName)
        
        try data.write(to: pdfURL)
        
        return pdfURL
    }
    
    // MARK: - Drawing Methods
    
    /// Disegna l'intestazione del PDF
    private func drawHeader(
        rect: CGRect,
        yPosition: CGFloat,
        settings: YachtSettings,
        month: Date
    ) -> CGFloat {
        var y = yPosition
        
        // Titolo principale
        let title = "EXPENSE REPORT"
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (rect.width - titleSize.width) / 2
        title.draw(at: CGPoint(x: titleX, y: y), withAttributes: titleAttributes)
        y += titleSize.height + 10
        
        // Sottotitolo con mese
        let monthText = formatMonth(month)
        let subtitleFont = UIFont.systemFont(ofSize: 20)
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.gray
        ]
        let subtitleSize = monthText.size(withAttributes: subtitleAttributes)
        let subtitleX = (rect.width - subtitleSize.width) / 2
        monthText.draw(at: CGPoint(x: subtitleX, y: y), withAttributes: subtitleAttributes)
        y += subtitleSize.height + 20
        
        // Linea separatrice
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 40, y: y))
        linePath.addLine(to: CGPoint(x: rect.width - 40, y: y))
        UIColor.lightGray.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()
        y += 20
        
        // Info Yacht
        let infoFont = UIFont.systemFont(ofSize: 11)
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        let yachtInfo = [
            "Yacht: \(settings.yachtName)",
            "Captain: \(settings.captainName)"
        ]
        
        for info in yachtInfo {
            info.draw(at: CGPoint(x: 40, y: y), withAttributes: infoAttributes)
            y += 16
        }
        
        return y
    }
    
    /// Disegna il sommario
    private func drawSummary(
        rect: CGRect,
        yPosition: CGFloat,
        expenses: [Expense]
    ) -> CGFloat {
        let y = yPosition

        let totalAmount = expenses.reduce(0) { $0 + $1.amount }

        // Background box (ridotto in altezza senza transaction count)
        let boxRect = CGRect(x: 40, y: y, width: rect.width - 80, height: 50)
        let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 8)
        UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0).setFill()
        boxPath.fill()

        // Total Amount (centrato verticalmente)
        let totalText = String(format: "TOTAL: €%.2f", totalAmount)
        let totalFont = UIFont.boldSystemFont(ofSize: 20)
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: totalFont,
            .foregroundColor: UIColor.black
        ]
        let totalSize = totalText.size(withAttributes: totalAttributes)
        let totalX = (rect.width - totalSize.width) / 2
        totalText.draw(at: CGPoint(x: totalX, y: y + 15), withAttributes: totalAttributes)

        return y + 60
    }
    
    /// Disegna la tabella delle spese riepilogativa
    private func drawExpenseTable(
        in context: UIGraphicsPDFRendererContext,
        rect: CGRect,
        yPosition: CGFloat,
        expenses: [Expense]
    ) -> CGFloat {
        var y = yPosition
        let leftMargin: CGFloat = 40
        let rightMargin: CGFloat = 40
        let tableWidth = rect.width - leftMargin - rightMargin
        
        // Colonne: Count, Category, %, Amount (invertiti)
        let countWidth: CGFloat = tableWidth * 0.15
        let categoryWidth: CGFloat = tableWidth * 0.45
        let percentWidth: CGFloat = tableWidth * 0.15
        let amountWidth: CGFloat = tableWidth * 0.25
        
        // Header della tabella
        let headerFont = UIFont.boldSystemFont(ofSize: 11)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.white
        ]
        
        // Background header
        let headerRect = CGRect(x: leftMargin, y: y, width: tableWidth, height: 30)
        UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).setFill()
        UIBezierPath(rect: headerRect).fill()
        
        // Header text (Amount e % invertiti)
        "Count".draw(at: CGPoint(x: leftMargin + 8, y: y + 8), withAttributes: headerAttributes)
        "Category".draw(at: CGPoint(x: leftMargin + countWidth + 8, y: y + 8), withAttributes: headerAttributes)
        "%".draw(at: CGPoint(x: leftMargin + countWidth + categoryWidth + 8, y: y + 8), withAttributes: headerAttributes)
        "Amount".draw(at: CGPoint(x: leftMargin + countWidth + categoryWidth + percentWidth + 8, y: y + 8), withAttributes: headerAttributes)
        
        y += 30
        
        // Calcola totale per percentuali
        let totalAmount = expenses.reduce(0) { $0 + $1.amount }
        
        // Raggruppa per categoria
        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Unknown" }
        let categoryTotals = grouped.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }, count: $0.value.count) }
            .sorted { $0.total > $1.total }
        
        // Celle dati
        let cellFont = UIFont.systemFont(ofSize: 10)
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: cellFont,
            .foregroundColor: UIColor.black
        ]
        
        var isAlternate = false
        
        for item in categoryTotals {
            // Alternate row color
            if isAlternate {
                let rowRect = CGRect(x: leftMargin, y: y, width: tableWidth, height: 25)
                UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0).setFill()
                UIBezierPath(rect: rowRect).fill()
            }
            
            let percentage = totalAmount > 0 ? (item.total / totalAmount) * 100 : 0

            // Draw cells (% e Amount invertiti)
            "\(item.count)".draw(at: CGPoint(x: leftMargin + 8, y: y + 6), withAttributes: cellAttributes)
            item.category.draw(at: CGPoint(x: leftMargin + countWidth + 8, y: y + 6), withAttributes: cellAttributes)
            String(format: "%.1f%%", percentage).draw(at: CGPoint(x: leftMargin + countWidth + categoryWidth + 8, y: y + 6), withAttributes: cellAttributes)
            String(format: "€%.2f", item.total).draw(at: CGPoint(x: leftMargin + countWidth + categoryWidth + percentWidth + 8, y: y + 6), withAttributes: cellAttributes)
            
            y += 25
            isAlternate.toggle()
        }
        
        // Footer con totale
        y += 10
        let footerRect = CGRect(x: leftMargin, y: y, width: tableWidth, height: 30)
        UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).setFill()
        UIBezierPath(rect: footerRect).fill()
        
        let footerFont = UIFont.boldSystemFont(ofSize: 12)
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.black
        ]
        
        "TOTAL".draw(at: CGPoint(x: leftMargin + countWidth + 8, y: y + 8), withAttributes: footerAttributes)
        "100%".draw(at: CGPoint(x: leftMargin + countWidth + categoryWidth + 8, y: y + 8), withAttributes: footerAttributes)
        String(format: "€%.2f", totalAmount).draw(at: CGPoint(x: leftMargin + countWidth + categoryWidth + percentWidth + 8, y: y + 8), withAttributes: footerAttributes)

        return y + 30
    }

    /// Disegna la tabella dettagliata delle spese per giorno
    private func drawDetailedExpenseTable(
        in context: UIGraphicsPDFRendererContext,
        rect: CGRect,
        yPosition: CGFloat,
        expenses: [Expense],
        month: Date
    ) {
        var y = yPosition
        let leftMargin: CGFloat = 40
        let rightMargin: CGFloat = 40
        let tableWidth = rect.width - leftMargin - rightMargin

        // Title
        let titleFont = UIFont.boldSystemFont(ofSize: 14)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        "DETAILED EXPENSES".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
        y += 25

        // Column widths
        let dayWidth: CGFloat = tableWidth * 0.15
        let categoryWidth: CGFloat = tableWidth * 0.55
        let amountWidth: CGFloat = tableWidth * 0.30

        // Header
        let headerFont = UIFont.boldSystemFont(ofSize: 10)
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.white
        ]

        let headerRect = CGRect(x: leftMargin, y: y, width: tableWidth, height: 25)
        UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).setFill()
        UIBezierPath(rect: headerRect).fill()

        "Day".draw(at: CGPoint(x: leftMargin + 8, y: y + 7), withAttributes: headerAttributes)
        "Category".draw(at: CGPoint(x: leftMargin + dayWidth + 8, y: y + 7), withAttributes: headerAttributes)
        "Amount".draw(at: CGPoint(x: leftMargin + dayWidth + categoryWidth + 8, y: y + 7), withAttributes: headerAttributes)

        y += 25

        // Get all days in month
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: month)!
        let year = calendar.component(.year, from: month)
        let monthComponent = calendar.component(.month, from: month)

        // Group expenses by day
        let expensesByDay = Dictionary(grouping: expenses) { expense -> Int in
            return calendar.component(.day, from: expense.date)
        }

        // Cell font
        let cellFont = UIFont.systemFont(ofSize: 9)
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: cellFont,
            .foregroundColor: UIColor.black
        ]

        var isAlternate = false

        // Iterate through all days
        for day in range {
            guard let dateComponents = DateComponents(calendar: calendar, year: year, month: monthComponent, day: day).date else { continue }

            let expensesForDay = expensesByDay[day] ?? []

            if expensesForDay.isEmpty {
                continue // Skip days without expenses
            }

            // Group by category for this day
            let categorizedExpenses = Dictionary(grouping: expensesForDay) { $0.category?.name ?? "Unknown" }
            let dayTotal = expensesForDay.reduce(0) { $0 + $1.amount }

            var isFirstRowForDay = true

            for (categoryName, categoryExpenses) in categorizedExpenses.sorted(by: { $0.key < $1.key }) {
                // Check if we need a new page
                if y > rect.height - 100 {
                    context.beginPage()
                    y = 40
                }

                // Alternate row color
                if isAlternate {
                    let rowRect = CGRect(x: leftMargin, y: y, width: tableWidth, height: 20)
                    UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0).setFill()
                    UIBezierPath(rect: rowRect).fill()
                }

                let categoryTotal = categoryExpenses.reduce(0) { $0 + $1.amount }

                // Day (only on first row)
                if isFirstRowForDay {
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "MMM d"
                    let dayText = dayFormatter.string(from: dateComponents)
                    dayText.draw(at: CGPoint(x: leftMargin + 8, y: y + 5), withAttributes: cellAttributes)
                }

                // Category and amount
                "\(categoryName) €\(String(format: "%.2f", categoryTotal))".draw(at: CGPoint(x: leftMargin + dayWidth + 8, y: y + 5), withAttributes: cellAttributes)

                // Day total (only on first row)
                if isFirstRowForDay {
                    String(format: "€%.2f", dayTotal).draw(at: CGPoint(x: leftMargin + dayWidth + categoryWidth + 8, y: y + 5), withAttributes: cellAttributes)
                    isFirstRowForDay = false
                }

                y += 20
                isAlternate.toggle()
            }
        }
    }

    // MARK: - Helper Methods
    
    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
    
    private func formatDateForFileName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
