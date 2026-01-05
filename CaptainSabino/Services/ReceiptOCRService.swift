//
//  ReceiptOCRService.swift
//  CaptainSabino
//
//  Servizio per OCR degli scontrini usando Claude Vision API
//

import Foundation
import UIKit
import SwiftData
import PDFKit

// MARK: - Data Models

enum ConfidenceLevel {
    case high    // Amount + Category trovati
    case medium  // Solo Amount trovato
    case low     // Niente trovato
}

struct ReceiptData {
    var amount: Double?
    var date: Date?
    var merchantName: String?
    var categoryName: String?
    var fullText: String
    var confidence: ConfidenceLevel

    var hasAmount: Bool { amount != nil }
    var hasCategory: Bool { categoryName != nil }
    var hasDate: Bool { date != nil }
    var hasMerchant: Bool { merchantName != nil && !merchantName!.isEmpty }
}

// MARK: - Claude API Response

private struct ClaudeReceiptResponse {
    var amount: Double?
    var date: Date?
    var merchant: String?
    var category: String?
}

// MARK: - Receipt OCR Service

class ReceiptOCRService {

    // MARK: - Singleton

    static let shared = ReceiptOCRService()

    private init() {}

    // MARK: - Constants

    private let maxImageWidth: CGFloat = 1200
    private let jpegQuality: CGFloat = 0.7

    // Valid categories (must match exactly)
    private let validCategories: Set<String> = [
        "Food", "Supermarket", "Fuel", "Pharmacy", "Chandlery",
        "Parking", "Tender Fuel", "Fly", "Crew"
    ]

    // MARK: - Public Methods

    /// Processa un'immagine di scontrino con Claude Vision
    /// - Parameters:
    ///   - image: UIImage dello scontrino
    ///   - claudeAPIKey: Chiave API Claude (REQUIRED)
    ///   - learnedKeywords: Keyword apprese per override categoria
    /// - Returns: ReceiptData con informazioni estratte
    func processReceipt(
        image: UIImage,
        claudeAPIKey: String?,
        learnedKeywords: [LearnedKeyword] = []
    ) async -> ReceiptData {

        // Verifica API key
        guard let apiKey = claudeAPIKey, !apiKey.isEmpty else {
            print("❌ Claude API key is required")
            return ReceiptData(
                amount: nil,
                date: nil,
                merchantName: nil,
                categoryName: nil,
                fullText: "",
                confidence: .low
            )
        }

        // Chiama Claude Vision API
        let claudeResponse = await callClaudeVisionAPI(image: image, apiKey: apiKey)

        // Se Claude non ha trovato nulla
        guard claudeResponse.amount != nil || claudeResponse.merchant != nil else {
            print("❌ Claude could not extract data from receipt")
            return ReceiptData(
                amount: nil,
                date: nil,
                merchantName: nil,
                categoryName: nil,
                fullText: "",
                confidence: .low
            )
        }

        // Determina categoria finale usando learned keywords
        let finalCategory = determineFinalCategory(
            claudeSuggestion: claudeResponse.category,
            merchantName: claudeResponse.merchant,
            learnedKeywords: learnedKeywords
        )

        // Calcola confidence
        let confidence = determineConfidence(
            hasAmount: claudeResponse.amount != nil,
            hasCategory: finalCategory != nil
        )

        print("✅ Receipt processed - Amount: €\(claudeResponse.amount?.description ?? "nil"), Merchant: \(claudeResponse.merchant ?? "nil"), Category: \(finalCategory ?? "nil")")

        return ReceiptData(
            amount: claudeResponse.amount,
            date: claudeResponse.date,
            merchantName: claudeResponse.merchant,
            categoryName: finalCategory,
            fullText: claudeResponse.merchant ?? "", // Per learning usiamo merchant name
            confidence: confidence
        )
    }

    // MARK: - Invoice Processing

    /// Processa un PDF di fattura con Claude Vision
    /// - Parameters:
    ///   - pdfURL: URL del file PDF
    ///   - claudeAPIKey: Chiave API Claude (REQUIRED)
    ///   - learnedKeywords: Keyword apprese per override categoria
    /// - Returns: ReceiptData con informazioni estratte
    func processInvoice(
        pdfURL: URL,
        claudeAPIKey: String?,
        learnedKeywords: [LearnedKeyword] = []
    ) async -> ReceiptData {

        // Verifica API key
        guard let apiKey = claudeAPIKey, !apiKey.isEmpty else {
            print("❌ Claude API key is required")
            return ReceiptData(
                amount: nil,
                date: nil,
                merchantName: nil,
                categoryName: nil,
                fullText: "",
                confidence: .low
            )
        }

        // Converti tutte le pagine del PDF in immagini
        let pdfImages = extractImagesFromPDF(url: pdfURL)

        guard !pdfImages.isEmpty else {
            print("❌ Could not extract images from PDF")
            return ReceiptData(
                amount: nil,
                date: nil,
                merchantName: nil,
                categoryName: nil,
                fullText: "",
                confidence: .low
            )
        }

        print("📄 Extracted \(pdfImages.count) page(s) from PDF")

        // Chiama Claude Vision API con tutte le pagine
        let claudeResponse = await callClaudeVisionAPIForInvoice(images: pdfImages, apiKey: apiKey)

        // Se Claude non ha trovato nulla
        guard claudeResponse.amount != nil || claudeResponse.merchant != nil else {
            print("❌ Claude could not extract data from invoice")
            return ReceiptData(
                amount: nil,
                date: nil,
                merchantName: nil,
                categoryName: nil,
                fullText: "",
                confidence: .low
            )
        }

        // Determina categoria finale usando learned keywords
        let finalCategory = determineFinalCategory(
            claudeSuggestion: claudeResponse.category,
            merchantName: claudeResponse.merchant,
            learnedKeywords: learnedKeywords
        )

        // Calcola confidence
        let confidence = determineConfidence(
            hasAmount: claudeResponse.amount != nil,
            hasCategory: finalCategory != nil
        )

        print("✅ Invoice processed - Amount: €\(claudeResponse.amount?.description ?? "nil"), Supplier: \(claudeResponse.merchant ?? "nil"), Category: \(finalCategory ?? "nil")")

        return ReceiptData(
            amount: claudeResponse.amount,
            date: claudeResponse.date,
            merchantName: claudeResponse.merchant,
            categoryName: finalCategory,
            fullText: claudeResponse.merchant ?? "",
            confidence: confidence
        )
    }

    /// Estrae immagini da tutte le pagine di un PDF
    private func extractImagesFromPDF(url: URL) -> [UIImage] {
        guard let pdfDocument = PDFDocument(url: url) else {
            print("❌ Could not open PDF document")
            return []
        }

        var images: [UIImage] = []
        let pageCount = pdfDocument.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            let pageRect = page.bounds(for: .mediaBox)

            // Scala per buona qualità (2x)
            let scale: CGFloat = 2.0
            let scaledSize = CGSize(
                width: pageRect.width * scale,
                height: pageRect.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: scaledSize))

                ctx.cgContext.translateBy(x: 0, y: scaledSize.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)

                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            images.append(image)
        }

        return images
    }

    /// Chiama Claude Vision API per analizzare la fattura (multi-pagina)
    private func callClaudeVisionAPIForInvoice(images: [UIImage], apiKey: String) async -> ClaudeReceiptResponse {

        // Prepara array di contenuti per le immagini
        var contentArray: [[String: Any]] = []

        for (index, image) in images.enumerated() {
            let processedImage = resizeImage(image)
            guard let imageData = processedImage.jpegData(compressionQuality: jpegQuality) else {
                print("❌ Failed to convert page \(index + 1) to JPEG")
                continue
            }

            let imageSizeMB = Double(imageData.count) / 1_048_576.0
            print("📏 Page \(index + 1) size: \(String(format: "%.2f", imageSizeMB)) MB")

            let base64Image = imageData.base64EncodedString()

            contentArray.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64Image
                ]
            ])
        }

        // Aggiungi il prompt alla fine
        let prompt = buildInvoicePrompt()
        contentArray.append([
            "type": "text",
            "text": prompt
        ])

        // Request body
        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 400,
            "messages": [
                [
                    "role": "user",
                    "content": contentArray
                ]
            ]
        ]

        // API call
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            print("❌ Invalid API URL")
            return ClaudeReceiptResponse()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60 // Più tempo per multi-pagina

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            print("🔄 Calling Claude Vision API for invoice (\(images.count) pages)...")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ No HTTP response")
                return ClaudeReceiptResponse()
            }

            print("📡 Claude API Status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("❌ Claude API error: \(errorBody)")
                }
                return ClaudeReceiptResponse()
            }

            // Parse response
            return parseClaudeResponse(data)

        } catch {
            print("❌ Claude API network error: \(error.localizedDescription)")
            return ClaudeReceiptResponse()
        }
    }

    /// Costruisce il prompt specifico per fatture
    private func buildInvoicePrompt() -> String {
        return """
        Analyze this invoice document and extract the following information.

        INSTRUCTIONS:
        1. AMOUNT: Find the TOTAL INVOICE AMOUNT (final amount to pay)
           - Look for keywords: "Totale Fattura", "Totale Documento", "Netto a Pagare", "Importo Totale", "Total Amount", "Amount Due"
           - This should be the FINAL amount including VAT/IVA
           - If you see "Imponibile" + "IVA", sum them for the total
           - Return as a number with 2 decimals (e.g., 1250.00)

        2. DATE: Find the INVOICE DATE (emission date, not payment due date)
           - Look for keywords: "Data Fattura", "Data Emissione", "Invoice Date", "Date"
           - Return in YYYY-MM-DD format (e.g., 2024-12-23)
           - DATE FORMAT: European format (DD/MM/YYYY) is most common for invoices

        3. SUPPLIER: Extract the supplier/vendor company name
           - Usually at the top of the invoice with logo
           - Include the company name (e.g., "ABC Services SRL", "Marine Supplies Ltd")
           - This is who ISSUED the invoice, not who receives it

        4. CATEGORY: Suggest ONE category from this EXACT list based on the invoice content:
           - "Food" → Food supplies, catering, restaurants
           - "Supermarket" → Grocery supplies
           - "Fuel" → Fuel, gas, diesel for main vessel
           - "Pharmacy" → Medical supplies, pharmacy
           - "Chandlery" → Marine/nautical supplies, boat equipment, hardware
           - "Parking" → Parking fees, garage services
           - "Tender Fuel" → Fuel for dinghies/tenders (small boats)
           - "Fly" → Flights, airline tickets, airport services
           - "Crew" → Crew services, uniforms, training

        RESPONSE FORMAT:
        Reply with ONLY a JSON object, no other text:
        {"amount": 1250.00, "date": "2024-12-23", "merchant": "ABC Services SRL", "category": "Chandlery"}

        If you cannot determine a value with confidence, use null:
        {"amount": 1250.00, "date": null, "merchant": "Unknown Supplier", "category": null}
        """
    }

    // MARK: - Claude Vision API

    /// Chiama Claude Vision API per analizzare lo scontrino
    private func callClaudeVisionAPI(image: UIImage, apiKey: String) async -> ClaudeReceiptResponse {

        // Ridimensiona e comprimi immagine
        let processedImage = resizeImage(image)
        guard let imageData = processedImage.jpegData(compressionQuality: jpegQuality) else {
            print("❌ Failed to convert image to JPEG")
            return ClaudeReceiptResponse()
        }

        let imageSizeMB = Double(imageData.count) / 1_048_576.0
        print("📏 Image size for Claude: \(String(format: "%.2f", imageSizeMB)) MB")

        let base64Image = imageData.base64EncodedString()

        // Costruisci il prompt
        let prompt = buildPrompt()

        // Request body
        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 300,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        // API call
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            print("❌ Invalid API URL")
            return ClaudeReceiptResponse()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            print("🔄 Calling Claude Vision API...")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ No HTTP response")
                return ClaudeReceiptResponse()
            }

            print("📡 Claude API Status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("❌ Claude API error: \(errorBody)")
                }
                return ClaudeReceiptResponse()
            }

            // Parse response
            return parseClaudeResponse(data)

        } catch {
            print("❌ Claude API network error: \(error.localizedDescription)")
            return ClaudeReceiptResponse()
        }
    }

    /// Costruisce il prompt per Claude Vision
    private func buildPrompt() -> String {
        return """
        Analyze this receipt image and extract the following information.

        INSTRUCTIONS:
        1. AMOUNT: Find the TOTAL PAID amount (final amount including tax/VAT)
           - Look for keywords: "TOTALE", "PAGATO", "CARTA", "CONTANTI", "BANCOMAT", "TOTAL", "IMPORTO"
           - This is the FINAL amount the customer paid, NOT subtotals or individual items
           - Return as a number with 2 decimals (e.g., 45.50)

        2. DATE: Find the receipt date
           - Usually printed at the top or bottom of the receipt
           - Return in YYYY-MM-DD format (e.g., 2024-12-23)
           - IMPORTANT: All dates are in EUROPEAN format DD/MM/YYYY (day/month/year)
           - Example: 25/01/2024 means January 25, 2024

        3. MERCHANT: Extract the store/business name
           - Usually the first 1-2 lines of the receipt
           - Include the brand name (e.g., "CONAD", "ENI", "Ristorante Da Mario")
           - Clean up any OCR artifacts

        4. CATEGORY: Suggest ONE category from this EXACT list:
           - "Food" → Restaurants, bars, pizzerias, cafes, trattorias, bakeries
           - "Supermarket" → Grocery stores (CONAD, COOP, LIDL, ESSELUNGA, etc.)
           - "Fuel" → Gas stations (ENI, Q8, SHELL, IP, etc.)
           - "Pharmacy" → Pharmacies, drugstores
           - "Chandlery" → Marine/nautical supplies, boat equipment
           - "Parking" → Parking lots, parking meters, garages
           - "Tender Fuel" → Fuel specifically for dinghies/tenders
           - "Fly" → Airports, airlines, flights
           - "Crew" → Salaries, payroll, crew expenses

        RESPONSE FORMAT:
        Reply with ONLY a JSON object, no other text:
        {"amount": 45.50, "date": "2024-12-23", "merchant": "Bar Roma", "category": "Food"}

        If you cannot determine a value with confidence, use null:
        {"amount": 45.50, "date": null, "merchant": "Unknown Store", "category": null}
        """
    }

    /// Parse della risposta Claude
    private func parseClaudeResponse(_ data: Data) -> ClaudeReceiptResponse {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                print("❌ Invalid Claude response structure")
                return ClaudeReceiptResponse()
            }

            print("📝 Claude response: \(text)")

            // Pulisci la risposta da eventuali backtick markdown
            let cleanedText = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            print("🧹 Cleaned JSON: \(cleanedText)")

            // Estrai JSON dalla risposta
            guard let jsonData = cleanedText.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("❌ Failed to parse Claude JSON")
                return ClaudeReceiptResponse()
            }

            // Parse amount
            var amount: Double?
            if let amountValue = parsed["amount"] as? Double {
                amount = amountValue
            } else if let amountInt = parsed["amount"] as? Int {
                amount = Double(amountInt)
            }

            // Parse date
            var date: Date?
            if let dateString = parsed["date"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                date = formatter.date(from: dateString)
            }

            // Parse merchant
            let merchant = parsed["merchant"] as? String

            // Parse category (validate against valid list)
            var category: String?
            if let categoryValue = parsed["category"] as? String,
               validCategories.contains(categoryValue) {
                category = categoryValue
            }

            print("🔍 Parsed - Amount: \(amount?.description ?? "nil"), Date: \(date?.description ?? "nil"), Merchant: \(merchant ?? "nil"), Category: \(category ?? "nil")")

            return ClaudeReceiptResponse(
                amount: amount,
                date: date,
                merchant: merchant,
                category: category
            )

        } catch {
            print("❌ Error parsing Claude response: \(error)")
            return ClaudeReceiptResponse()
        }
    }

    // MARK: - Category Logic with Learned Keywords

    /// Determina la categoria finale usando learned keywords
    /// - Parameters:
    ///   - claudeSuggestion: Categoria suggerita da Claude
    ///   - merchantName: Nome del merchant estratto
    ///   - learnedKeywords: Keyword apprese dall'utente
    /// - Returns: Categoria finale
    private func determineFinalCategory(
        claudeSuggestion: String?,
        merchantName: String?,
        learnedKeywords: [LearnedKeyword]
    ) -> String? {

        guard !learnedKeywords.isEmpty else {
            // Nessuna keyword appresa, usa suggerimento Claude
            print("ℹ️ No learned keywords, using Claude suggestion: \(claudeSuggestion ?? "nil")")
            return claudeSuggestion
        }

        // Prepara testo per matching (merchant name uppercased)
        let searchText = (merchantName ?? "").uppercased()

        guard !searchText.isEmpty else {
            return claudeSuggestion
        }

        // Cerca match nelle learned keywords
        // Ordina per usageCount (keyword più usate hanno priorità)
        let sortedKeywords = learnedKeywords.sorted { $0.usageCount > $1.usageCount }

        for keyword in sortedKeywords {
            if searchText.contains(keyword.keyword.uppercased()) {
                print("🎯 Learned keyword match: '\(keyword.keyword)' → \(keyword.categoryName) (used \(keyword.usageCount) times)")
                return keyword.categoryName
            }
        }

        // Nessun match, usa suggerimento Claude
        print("ℹ️ No keyword match, using Claude suggestion: \(claudeSuggestion ?? "nil")")
        return claudeSuggestion
    }

    // MARK: - Keyword Learning

    /// Estrae keyword significative dal nome del merchant per learning
    /// - Parameter merchantName: Nome merchant da Claude
    /// - Returns: Array di keyword da salvare
    func extractMerchantKeywords(from merchantName: String) -> [String] {
        guard !merchantName.isEmpty else { return [] }

        // Parole da escludere (troppo generiche)
        let excludeWords: Set<String> = [
            "SRL", "SPA", "SAS", "SNC", "SRLS", "SpA", "S.R.L.", "S.P.A.",
            "DI", "DA", "DEL", "DELLA", "DELLO", "DEGLI", "DELLE",
            "IL", "LA", "LO", "LE", "GLI", "UN", "UNA", "I",
            "VIA", "VIALE", "PIAZZA", "CORSO", "LARGO",
            "N.", "NR", "TEL", "FAX", "P.IVA", "C.F.",
            "RICEVUTA", "SCONTRINO", "FISCALE"
        ]

        // Estrai parole significative
        let words = merchantName
            .uppercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { word in
                word.count >= 3 &&  // Almeno 3 caratteri
                !excludeWords.contains(word) &&
                !word.allSatisfy { $0.isNumber }  // Non solo numeri
            }

        // Rimuovi duplicati e limita a 3
        let uniqueKeywords = Array(Set(words)).prefix(3)

        print("📚 Keywords for learning: \(uniqueKeywords.joined(separator: ", "))")

        return Array(uniqueKeywords)
    }

    // MARK: - Helper Methods

    /// Ridimensiona immagine per rispettare limiti API
    private func resizeImage(_ image: UIImage) -> UIImage {
        let width = image.size.width

        guard width > maxImageWidth else {
            return image
        }

        let scaleFactor = maxImageWidth / width
        let newHeight = image.size.height * scaleFactor
        let newSize = CGSize(width: maxImageWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    /// Determina il livello di confidence
    private func determineConfidence(hasAmount: Bool, hasCategory: Bool) -> ConfidenceLevel {
        if hasAmount && hasCategory {
            return .high
        } else if hasAmount {
            return .medium
        } else {
            return .low
        }
    }
}
