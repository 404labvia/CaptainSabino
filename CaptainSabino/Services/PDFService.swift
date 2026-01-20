//
//  PDFService.swift
//  YachtExpense
//
//  Servizio per generazione PDF con UIGraphicsPDFRenderer
//

import Foundation
import UIKit

// MARK: - Report Info Model

struct ReportInfo: Identifiable {
    let id = UUID()
    let url: URL
    let month: Date

    /// Mese formattato (es. "December 2025")
    var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    /// Anno e mese breve (es. "Dec 2025")
    var shortMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: month)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// Crea UIColor da stringa HEX
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        default:
            (r, g, b) = (128, 128, 128) // Fallback a grigio
        }

        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        )
    }
}

class PDFService {
    // MARK: - Singleton

    static let shared = PDFService()

    /// Flag per indicare se iCloud è disponibile
    private(set) var isICloudAvailable = false

    private init() {
        // Verifica disponibilità iCloud e migra se necessario
        checkICloudAvailability()
        migrateLocalPDFsToICloud()
    }

    // MARK: - iCloud Drive Support

    /// Identificatore container iCloud (usa il bundle ID con tildes)
    /// Per bundle ID "it.404lab.CaptainSabino" → "iCloud~it~404lab~CaptainSabino"
    private var iCloudContainerIdentifier: String {
        "iCloud.it.404lab.CaptainSabino"
    }

    /// Cartella iCloud Drive per i report
    private var iCloudReportsDirectory: URL? {
        guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) else {
            return nil
        }

        let documentsURL = iCloudURL.appendingPathComponent("Documents")
        let reportsURL = documentsURL.appendingPathComponent("Reports")

        // Crea la cartella se non esiste
        if !FileManager.default.fileExists(atPath: reportsURL.path) {
            try? FileManager.default.createDirectory(at: reportsURL, withIntermediateDirectories: true)
        }

        return reportsURL
    }

    /// Cartella locale per i report PDF (fallback)
    private var localReportsDirectory: URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let reportsPath = documentsPath.appendingPathComponent("Reports", isDirectory: true)

        // Crea la cartella se non esiste
        if !FileManager.default.fileExists(atPath: reportsPath.path) {
            try? FileManager.default.createDirectory(at: reportsPath, withIntermediateDirectories: true)
        }

        return reportsPath
    }

    /// Cartella report attiva (iCloud se disponibile, altrimenti locale)
    private var reportsDirectory: URL? {
        if isICloudAvailable, let iCloudDir = iCloudReportsDirectory {
            return iCloudDir
        }
        return localReportsDirectory
    }

    /// Verifica disponibilità iCloud Drive
    private func checkICloudAvailability() {
        if FileManager.default.ubiquityIdentityToken != nil {
            // iCloud account disponibile
            if let _ = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) {
                isICloudAvailable = true
                print("✅ iCloud Drive disponibile per i report PDF")
            } else {
                isICloudAvailable = false
                print("⚠️ iCloud container non configurato")
            }
        } else {
            isICloudAvailable = false
            print("⚠️ iCloud non disponibile - utilizzo storage locale")
        }
    }

    /// Migra i PDF locali su iCloud Drive (se disponibile)
    private func migrateLocalPDFsToICloud() {
        guard isICloudAvailable,
              let localDir = localReportsDirectory,
              let iCloudDir = iCloudReportsDirectory else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            do {
                let localFiles = try FileManager.default.contentsOfDirectory(at: localDir, includingPropertiesForKeys: nil)
                let pdfFiles = localFiles.filter { $0.pathExtension.lowercased() == "pdf" }

                for localPDF in pdfFiles {
                    let iCloudDestination = iCloudDir.appendingPathComponent(localPDF.lastPathComponent)

                    // Sposta solo se non esiste già su iCloud
                    if !FileManager.default.fileExists(atPath: iCloudDestination.path) {
                        try FileManager.default.copyItem(at: localPDF, to: iCloudDestination)
                        print("✅ Migrato su iCloud: \(localPDF.lastPathComponent)")

                        // Rimuovi il file locale dopo la migrazione
                        try FileManager.default.removeItem(at: localPDF)
                    }
                }
            } catch {
                print("⚠️ Errore migrazione PDF su iCloud: \(error)")
            }
        }
    }

    // MARK: - Report Management

    /// Ottiene tutti i report salvati (da iCloud e locale, deduplicati)
    func getSavedReports() -> [ReportInfo] {
        var allReports: [ReportInfo] = []
        var seenFileNames: Set<String> = []

        // Prima cerca su iCloud (priorità)
        if isICloudAvailable, let iCloudDir = iCloudReportsDirectory {
            let iCloudReports = loadReports(from: iCloudDir)
            for report in iCloudReports {
                let fileName = report.url.lastPathComponent
                if !seenFileNames.contains(fileName) {
                    allReports.append(report)
                    seenFileNames.insert(fileName)
                }
            }
        }

        // Poi cerca localmente (per report non ancora migrati)
        if let localDir = localReportsDirectory {
            let localReports = loadReports(from: localDir)
            for report in localReports {
                let fileName = report.url.lastPathComponent
                if !seenFileNames.contains(fileName) {
                    allReports.append(report)
                    seenFileNames.insert(fileName)
                }
            }
        }

        return allReports.sorted { $0.month > $1.month }
    }

    /// Carica i report da una cartella specifica
    private func loadReports(from directory: URL) -> [ReportInfo] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            return files
                .filter { $0.pathExtension.lowercased() == "pdf" }
                .compactMap { url -> ReportInfo? in
                    // Estrai mese/anno dal nome file (ExpenseReport_YYYY-MM.pdf)
                    let fileName = url.deletingPathExtension().lastPathComponent
                    guard fileName.hasPrefix("ExpenseReport_"),
                          let dateString = fileName.components(separatedBy: "_").last,
                          let date = parseReportDate(dateString) else {
                        return nil
                    }
                    return ReportInfo(url: url, month: date)
                }
        } catch {
            print("❌ Error loading reports from \(directory.path): \(error)")
            return []
        }
    }

    /// Elimina un report
    func deleteReport(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Verifica se esiste un report per un mese specifico
    func reportExists(for month: Date) -> Bool {
        guard let reportsDir = reportsDirectory else { return false }
        let fileName = "ExpenseReport_\(formatDateForFileName(month)).pdf"
        let fileURL = reportsDir.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Parsing data dal nome file
    private func parseReportDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: dateString)
    }

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

            // Detailed Table (spostata sotto header, con riga TOTAL)
            yPosition = drawDetailedExpenseTable(in: context, rect: pageRect, yPosition: yPosition, expenses: expenses, month: month)

            yPosition += 40

            // Pie Chart (sostituisce la tabella category)
            drawPieChart(in: context, rect: pageRect, yPosition: yPosition, expenses: expenses)
        }

        // Salva il PDF nella cartella Reports
        let fileName = "ExpenseReport_\(formatDateForFileName(month)).pdf"
        guard let reportsDir = reportsDirectory else {
            throw NSError(domain: "PDFService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access reports directory"])
        }
        let pdfURL = reportsDir.appendingPathComponent(fileName)

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

        // Info Yacht (colonna sinistra) e Entry Type Legend (colonna destra)
        let infoFont = UIFont.systemFont(ofSize: 11)
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: UIColor.darkGray
        ]

        let legendFont = UIFont.systemFont(ofSize: 9)
        let legendAttributes: [NSAttributedString.Key: Any] = [
            .font: legendFont,
            .foregroundColor: UIColor.gray
        ]

        // Colonna sinistra - Yacht info
        let yachtY = y
        "Yacht: \(settings.yachtName)".draw(at: CGPoint(x: 40, y: y), withAttributes: infoAttributes)
        y += 16
        "Captain: \(settings.captainName)".draw(at: CGPoint(x: 40, y: y), withAttributes: infoAttributes)

        // Colonna destra - Entry Type Legend (allineata a destra)
        let rightColumnX: CGFloat = rect.width - 140
        "Entry Types:".draw(at: CGPoint(x: rightColumnX, y: yachtY), withAttributes: legendAttributes)
        "C = Cash".draw(at: CGPoint(x: rightColumnX, y: yachtY + 12), withAttributes: legendAttributes)
        "R = Receipt".draw(at: CGPoint(x: rightColumnX, y: yachtY + 24), withAttributes: legendAttributes)
        "I = Invoice".draw(at: CGPoint(x: rightColumnX, y: yachtY + 36), withAttributes: legendAttributes)

        y += 30

        return y
    }

    /// Disegna la tabella dettagliata delle spese per giorno (con riga TOTAL)
    private func drawDetailedExpenseTable(
        in context: UIGraphicsPDFRendererContext,
        rect: CGRect,
        yPosition: CGFloat,
        expenses: [Expense],
        month: Date
    ) -> CGFloat {
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
        let dayWidth: CGFloat = tableWidth * 0.12
        let categoryWidth: CGFloat = tableWidth * 0.48
        let typeWidth: CGFloat = tableWidth * 0.12
        let amountWidth: CGFloat = tableWidth * 0.28

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
        "Type".draw(at: CGPoint(x: leftMargin + dayWidth + categoryWidth + 8, y: y + 7), withAttributes: headerAttributes)
        "Amount".draw(at: CGPoint(x: leftMargin + dayWidth + categoryWidth + typeWidth + 8, y: y + 7), withAttributes: headerAttributes)

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

                // Category
                categoryName.draw(at: CGPoint(x: leftMargin + dayWidth + 8, y: y + 5), withAttributes: cellAttributes)

                // Entry types for this category (C/R/I)
                let entryTypes = Set(categoryExpenses.map { $0.entryType.displayLetter }).sorted().joined(separator: "/")
                entryTypes.draw(at: CGPoint(x: leftMargin + dayWidth + categoryWidth + 8, y: y + 5), withAttributes: cellAttributes)

                // Category total
                formatCurrency(categoryTotal).draw(at: CGPoint(x: leftMargin + dayWidth + categoryWidth + typeWidth + 8, y: y + 5), withAttributes: cellAttributes)

                isFirstRowForDay = false

                y += 20
                isAlternate.toggle()
            }
        }

        // Footer con riga TOTAL
        y += 10
        let totalAmount = expenses.reduce(0) { $0 + $1.amount }

        let footerRect = CGRect(x: leftMargin, y: y, width: tableWidth, height: 30)
        UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0).setFill()
        UIBezierPath(rect: footerRect).fill()

        let footerFont = UIFont.boldSystemFont(ofSize: 12)
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.black
        ]

        "TOTAL".draw(at: CGPoint(x: leftMargin + 8, y: y + 8), withAttributes: footerAttributes)
        formatCurrency(totalAmount).draw(at: CGPoint(x: leftMargin + dayWidth + categoryWidth + 8, y: y + 8), withAttributes: footerAttributes)

        return y + 40
    }

    /// Disegna il grafico a torta delle spese per categoria
    private func drawPieChart(
        in context: UIGraphicsPDFRendererContext,
        rect: CGRect,
        yPosition: CGFloat,
        expenses: [Expense]
    ) {
        let leftMargin: CGFloat = 40
        let chartSize: CGFloat = 200
        let centerX = rect.width / 2
        let centerY = yPosition + chartSize / 2
        let radius = chartSize / 2

        // Title
        let titleFont = UIFont.boldSystemFont(ofSize: 14)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        "EXPENSES BY CATEGORY".draw(at: CGPoint(x: leftMargin, y: yPosition - 25), withAttributes: titleAttributes)

        // Calculate total
        let totalAmount = expenses.reduce(0) { $0 + $1.amount }

        guard totalAmount > 0 else { return }

        // Group by category
        let categoryTotals = Dictionary(grouping: expenses) { expense -> String in
            return expense.category?.name ?? "Unknown"
        }.mapValues { expenses -> (amount: Double, color: String) in
            let amount = expenses.reduce(0) { $0 + $1.amount }
            let colorHex = expenses.first?.category?.colorHex ?? "#999999"
            return (amount, colorHex)
        }

        // Sort by amount (descending)
        let sortedCategories = categoryTotals.sorted { $0.value.amount > $1.value.amount }

        // Draw pie sectors
        var startAngle: CGFloat = -.pi / 2 // Start at top (12 o'clock)

        for (_, data) in sortedCategories {
            let percentage = data.amount / totalAmount
            let endAngle = startAngle + (2 * .pi * percentage)

            // Create pie sector path
            let path = UIBezierPath()
            path.move(to: CGPoint(x: centerX, y: centerY))
            path.addArc(
                withCenter: CGPoint(x: centerX, y: centerY),
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            path.close()

            // Fill with category color
            UIColor(hex: data.color).setFill()
            path.fill()

            // Draw border
            UIColor.white.setStroke()
            path.lineWidth = 2
            path.stroke()

            startAngle = endAngle
        }

        // Draw center circle with total
        let innerRadius: CGFloat = radius * 0.5
        let innerCircle = UIBezierPath(
            arcCenter: CGPoint(x: centerX, y: centerY),
            radius: innerRadius,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true
        )
        UIColor.white.setFill()
        innerCircle.fill()

        // Draw total amount in center
        let totalText = formatCurrency(totalAmount)
        let totalFont = UIFont.boldSystemFont(ofSize: 18)
        let totalAttributes: [NSAttributedString.Key: Any] = [
            .font: totalFont,
            .foregroundColor: UIColor.black
        ]
        let totalSize = totalText.size(withAttributes: totalAttributes)
        totalText.draw(
            at: CGPoint(
                x: centerX - totalSize.width / 2,
                y: centerY - totalSize.height / 2
            ),
            withAttributes: totalAttributes
        )

        // Draw legend
        var legendY = yPosition
        let legendX = centerX + radius + 30

        let legendFont = UIFont.systemFont(ofSize: 9)
        let legendAttributes: [NSAttributedString.Key: Any] = [
            .font: legendFont,
            .foregroundColor: UIColor.black
        ]

        for (categoryName, data) in sortedCategories {
            let percentage = (data.amount / totalAmount) * 100

            // Color square
            let colorRect = CGRect(x: legendX, y: legendY, width: 12, height: 12)
            UIColor(hex: data.color).setFill()
            UIBezierPath(rect: colorRect).fill()

            // Category name and percentage
            let legendText = "\(categoryName) - \(String(format: "%.1f%%", percentage))"
            legendText.draw(
                at: CGPoint(x: legendX + 18, y: legendY),
                withAttributes: legendAttributes
            )

            legendY += 18
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

    /// Formatta valuta in formato italiano: € 2.460,50
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "€ "
        formatter.currencyDecimalSeparator = ","
        formatter.currencyGroupingSeparator = "."
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "€ 0,00"
    }
}
