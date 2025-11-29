//
//  ReceiptOCRService.swift
//  CaptainSabino
//
//  Servizio per OCR (riconoscimento testo) dagli scontrini
//  Usa Apple Vision Framework + Claude API (opzionale)
//

import Foundation
import UIKit
import Vision
import SwiftData

// MARK: - Data Models

enum OCRSource {
    case appleVision
    case claude
    case hybrid
}

enum ConfidenceLevel {
    case high    // >80%
    case medium  // 50-80%
    case low     // <50%
}

struct ReceiptData {
    var amount: Double?
    var categoryName: String?
    var fullText: String
    var confidence: ConfidenceLevel
    var ocrSource: OCRSource

    var hasAmount: Bool { amount != nil }
    var hasCategory: Bool { categoryName != nil }
}

// MARK: - Receipt OCR Service

class ReceiptOCRService {

    // MARK: - Singleton

    static let shared = ReceiptOCRService()

    private init() {}

    // MARK: - Constants

    private let minAmount: Double = 0.10
    private let maxAmount: Double = 9999.99

    // MARK: - Category Keywords Database

    /// Mapping keywords -> category names
    /// Include brand europei comuni e parole chiave generiche
    private let categoryKeywords: [String: [String]] = [
        "Supermarket": [
            // Italia
            "CONAD", "CARREFOUR", "ESSELUNGA", "COOP", "LIDL", "EUROSPIN",
            "MD", "PENNY", "AUCHAN", "SIMPLY", "PAM", "SIGMA", "FAMILA",
            // Francia
            "LECLERC", "INTERMARCHE", "ALDI", "MONOPRIX", "FRANPRIX",
            // Spagna
            "MERCADONA", "DIA", "ALCAMPO",
            // Germania
            "REWE", "EDEKA", "KAUFLAND",
            // UK
            "TESCO", "SAINSBURY", "ASDA",
            // Generici
            "SUPERMARKET", "SUPERMERCATO", "SUPERMARKT", "MARKET", "GROCERY"
        ],

        "Fuel": [
            // Brand internazionali
            "ESSO", "ENI", "SHELL", "AGIP", "Q8", "TAMOIL", "BP", "TOTAL",
            "REPSOL", "IP", "KUWAIT", "GULF", "TEXACO", "MOBIL",
            // Italia
            "ERG", "API", "ESSO", "PETRONAS",
            // Generici
            "FUEL", "CARBURANTE", "BENZINA", "DIESEL", "GASOLIO",
            "STATION", "DISTRIBUTORE", "PETROL", "GAS STATION"
        ],

        "Pharmacy": [
            "FARMACIA", "PHARMACY", "APOTHEKE", "APOTEK", "PHARMACIE",
            "DROGUERIE", "LLOYDS", "BOOTS", "PARAFARMACIA",
            "FARMACIE", "APOTEKA"
        ],

        "Food": [
            "RISTORANTE", "RESTAURANT", "TRATTORIA", "PIZZERIA", "OSTERIA",
            "BAR", "CAFETERIA", "CAFE", "CAFFE", "TAVERNA", "BISTRO",
            "BRASSERIE", "PUB", "GASTHAUS", "TAVOLA", "CUCINA",
            "MCDONALD", "BURGER", "KFC", "SUBWAY"
        ],

        "Chandlery": [
            "CHANDLER", "NAUTICA", "MARINE", "SHIP", "BOAT", "YACHT",
            "CANTIERE", "SHIPYARD", "MARINERIA", "NAVALE", "MARITIME"
        ],

        "Water Test": [
            "WATER TEST", "ANALISI", "LABORATORIO", "LAB", "ANALYSIS",
            "TEST ACQUA", "WASSERTEST"
        ],

        "Welder": [
            "SALDATURE", "WELDING", "WELDER", "SALDATURA", "SCHWEISSEN",
            "SOUDURE", "CARPENTERIA", "METAL"
        ],

        "Tender Fuel": [
            "TENDER", "DINGHY", "GOMMONE", "ANNEX"
        ],

        "Fly": [
            "AIRPORT", "AEROPORTO", "FLUGHAFEN", "AEROPORT", "AIRLINE",
            "FLIGHT", "VOLO", "AIRWAYS", "RYANAIR", "EASYJET", "ALITALIA"
        ],

        "Crew": [
            "SALARY", "STIPENDIO", "WAGE", "PAYROLL", "SALAIRE",
            "CREW", "EQUIPAGGIO", "PERSONNEL", "STAFF"
        ]
    ]

    // MARK: - Public Methods

    /// Processa un'immagine di scontrino e estrae dati
    /// - Parameters:
    ///   - image: UIImage dello scontrino
    ///   - claudeAPIKey: Chiave API Claude (opzionale)
    /// - Returns: ReceiptData con informazioni estratte
    func processReceipt(
        image: UIImage,
        claudeAPIKey: String? = nil
    ) async -> ReceiptData {
        // Step 1: Apple Vision OCR
        let visionText = await performVisionOCR(on: image)

        guard !visionText.isEmpty else {
            return ReceiptData(
                amount: nil,
                categoryName: nil,
                fullText: "",
                confidence: .low,
                ocrSource: .appleVision
            )
        }

        // Step 2: Extract amount
        let extractedAmount = extractAmount(from: visionText)

        // Step 3: Keyword matching per categoria
        let matchedCategory = matchCategory(from: visionText)

        // Step 4: Determina confidence
        let confidence = determineConfidence(
            hasAmount: extractedAmount != nil,
            hasCategory: matchedCategory != nil
        )

        // Step 5: Se low confidence e Claude disponibile, usa API
        if confidence == .low, let apiKey = claudeAPIKey, !apiKey.isEmpty {
            return await processWithClaudeAPI(
                image: image,
                apiKey: apiKey,
                fallbackText: visionText
            )
        }

        // Ritorna risultato Apple Vision + Keywords
        return ReceiptData(
            amount: extractedAmount,
            categoryName: matchedCategory,
            fullText: visionText,
            confidence: confidence,
            ocrSource: matchedCategory != nil ? .hybrid : .appleVision
        )
    }

    // MARK: - Apple Vision OCR

    /// Esegue OCR con Apple Vision Framework
    /// - Parameter image: Immagine da processare
    /// - Returns: Testo estratto
    private func performVisionOCR(on image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            return ""
        }

        let request = VNRecognizeTextRequest()

        // Configurazione per scontrini europei
        request.recognitionLanguages = ["it-IT", "en-US", "fr-FR", "de-DE", "es-ES"]
        request.recognitionLevel = .accurate // Massima accuratezza
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let observations = request.results else {
                return ""
            }

            // Concatena tutto il testo riconosciuto
            let recognizedText = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")

            print("📄 OCR Text estratto (\(recognizedText.count) caratteri)")
            return recognizedText

        } catch {
            print("❌ Errore Vision OCR: \(error.localizedDescription)")
            return ""
        }
    }

    // MARK: - Amount Extraction

    /// Estrae l'importo totale dallo scontrino
    /// - Parameter text: Testo OCR
    /// - Returns: Importo estratto o nil
    private func extractAmount(from text: String) -> Double? {
        let normalizedText = text.uppercased()

        // PRIORITÀ 1: Pattern "PAGATO" / "CARTA" / "CONTANTI" (più affidabili!)
        let paymentPatterns = [
            "PAGATO[:\\s]*€?\\s*(\\d+[.,]\\d{2})",           // PAGATO 55.51
            "IMPORTO\\s+PAGATO[:\\s]*€?\\s*(\\d+[.,]\\d{2})", // IMPORTO PAGATO 55.51
            "PAGAMENTO[:\\s]*€?\\s*(\\d+[.,]\\d{2})",       // PAGAMENTO 55.51
            "CARTA[:\\s]*€?\\s*(\\d+[.,]\\d{2})",           // CARTA 55.51
            "CONTANTI[:\\s]*€?\\s*(\\d+[.,]\\d{2})",        // CONTANTI 55.51
            "BANCOMAT[:\\s]*€?\\s*(\\d+[.,]\\d{2})",        // BANCOMAT 55.51
            "CASH[:\\s]*€?\\s*(\\d+[.,]\\d{2})",            // CASH 55.51
            "PAID[:\\s]*€?\\s*(\\d+[.,]\\d{2})"             // PAID 55.51
        ]

        for pattern in paymentPatterns {
            if let amount = extractWithRegex(pattern: pattern, from: normalizedText) {
                print("✅ Amount trovato con pattern PAGATO: €\(amount)")
                return amount
            }
        }

        // PRIORITÀ 2: Pattern "TOTALE" (ma NON subtotale!)
        let totalPatterns = [
            "(?<!SUB)TOTALE[:\\s]*€?\\s*(\\d+[.,]\\d{2})",  // TOTALE (non SUBTOTALE)
            "TOT\\.?[:\\s]*€?\\s*(\\d+[.,]\\d{2})",         // TOT. 55.51
            "TOTAL[E]?[:\\s]*€?\\s*(\\d+[.,]\\d{2})",       // TOTAL / TOTALE
            "SUMA[:\\s]*€?\\s*(\\d+[.,]\\d{2})",            // SUMA (spagnolo)
            "GESAMT[:\\s]*€?\\s*(\\d+[.,]\\d{2})",          // GESAMT (tedesco)
            "SOMME[:\\s]*€?\\s*(\\d+[.,]\\d{2})",           // SOMME (francese)
        ]

        for pattern in totalPatterns {
            if let amount = extractWithRegex(pattern: pattern, from: normalizedText) {
                print("✅ Amount trovato con pattern TOTALE: €\(amount)")
                return amount
            }
        }

        // PRIORITÀ 3: Cerca nelle ultime righe (dove di solito c'è il totale)
        let lines = normalizedText.split(separator: "\n")
        let lastLines = Array(lines.suffix(8)) // Ultime 8 righe

        // Cerca pattern "qualsiasi parola seguita da numero" nelle ultime righe
        for line in lastLines.reversed() {
            // Pattern: parola + numero (es. "EURO 55.51", "SALDO 55.51")
            let linePattern = "[A-Z]+[:\\s]+€?\\s*(\\d+[.,]\\d{2})"
            if let amount = extractWithRegex(pattern: linePattern, from: String(line)) {
                // Escludi se la riga contiene "SUBTOT", "SUB", "IVA", "TAX"
                let lineStr = String(line)
                if !lineStr.contains("SUBTOT") &&
                   !lineStr.contains("SUB") &&
                   !lineStr.contains("IVA") &&
                   !lineStr.contains("TAX") &&
                   !lineStr.contains("VAT") {
                    print("✅ Amount trovato nelle ultime righe: €\(amount)")
                    return amount
                }
            }
        }

        // PRIORITÀ 4: Cerca € symbol + numero (prendi il più grande)
        let euroPattern = "€\\s*(\\d+[.,]\\d{2})"
        if let amounts = extractAllWithRegex(pattern: euroPattern, from: normalizedText) {
            // Filtra importi troppo piccoli (probabilmente IVA o singoli articoli)
            let significantAmounts = amounts.filter { $0 >= 1.00 }
            if let maxAmount = significantAmounts.max() {
                print("⚠️ Amount trovato con fallback (max €): €\(maxAmount)")
                return maxAmount
            }
        }

        print("❌ Nessun amount trovato")
        return nil
    }

    /// Estrae numero con regex
    /// - Parameters:
    ///   - pattern: Regex pattern
    ///   - text: Testo da cercare
    /// - Returns: Primo numero trovato
    private func extractWithRegex(pattern: String, from text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        // Estrai il gruppo di cattura (il numero)
        guard let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let numberString = String(text[numberRange])
        return parseAmount(numberString)
    }

    /// Estrae tutti i numeri con regex
    private func extractAllWithRegex(pattern: String, from text: String) -> [Double]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        let amounts = matches.compactMap { match -> Double? in
            guard let numberRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            let numberString = String(text[numberRange])
            return parseAmount(numberString)
        }

        return amounts.isEmpty ? nil : amounts
    }

    /// Converte stringa in Double (gestisce , e .)
    /// - Parameter string: Stringa numerica
    /// - Returns: Double parsed
    private func parseAmount(_ string: String) -> Double? {
        // Normalizza: 45,50 -> 45.50
        let normalized = string.replacingOccurrences(of: ",", with: ".")

        guard let amount = Double(normalized) else {
            return nil
        }

        // Valida range
        guard amount >= minAmount && amount <= maxAmount else {
            return nil
        }

        return amount
    }

    // MARK: - Category Matching

    /// Trova la categoria più probabile dal testo
    /// - Parameter text: Testo OCR
    /// - Returns: Nome categoria o nil
    private func matchCategory(from text: String) -> String? {
        let normalizedText = text.uppercased()

        var categoryScores: [String: Int] = [:]

        // Cerca keywords in ogni categoria
        for (categoryName, keywords) in categoryKeywords {
            var score = 0

            for keyword in keywords {
                if normalizedText.contains(keyword) {
                    // Peso maggiore per keyword più specifiche (lunghe)
                    score += keyword.count
                }
            }

            if score > 0 {
                categoryScores[categoryName] = score
            }
        }

        // Ritorna categoria con score più alto
        if let bestMatch = categoryScores.max(by: { $0.value < $1.value }) {
            print("✅ Categoria matched: \(bestMatch.key) (score: \(bestMatch.value))")
            return bestMatch.key
        }

        print("⚠️ Nessuna categoria matched")
        return nil
    }

    // MARK: - Confidence Calculation

    /// Determina il livello di confidenza
    /// - Parameters:
    ///   - hasAmount: Se l'importo è stato trovato
    ///   - hasCategory: Se la categoria è stata trovata
    /// - Returns: Livello di confidenza
    private func determineConfidence(hasAmount: Bool, hasCategory: Bool) -> ConfidenceLevel {
        if hasAmount && hasCategory {
            return .high
        } else if hasAmount || hasCategory {
            return .medium
        } else {
            return .low
        }
    }

    // MARK: - Claude API Integration

    /// Processa scontrino con Claude Vision API
    /// - Parameters:
    ///   - image: Immagine scontrino
    ///   - apiKey: Claude API key
    ///   - fallbackText: Testo già estratto da Vision (per merge)
    /// - Returns: ReceiptData da Claude
    private func processWithClaudeAPI(
        image: UIImage,
        apiKey: String,
        fallbackText: String
    ) async -> ReceiptData {

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return ReceiptData(
                amount: nil,
                categoryName: nil,
                fullText: fallbackText,
                confidence: .low,
                ocrSource: .appleVision
            )
        }

        let base64Image = imageData.base64EncodedString()

        // Costruisci request body
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 200,
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
                            "text": """
                            Extract the TOTAL AMOUNT (in euros) and CATEGORY from this receipt.

                            Available categories: Supermarket, Fuel, Pharmacy, Food, Crew, Chandlery, Water Test, Welder, Tender Fuel, Fly.

                            Reply ONLY with JSON format:
                            {"amount": 45.50, "category": "Supermarket"}

                            If you cannot determine amount or category, use null.
                            """
                        ]
                    ]
                ]
            ]
        ]

        // Chiamata API
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return fallbackData(fallbackText)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Claude API error: invalid response")
                return fallbackData(fallbackText)
            }

            // Parse response
            if let claudeData = parseClaudeResponse(data) {
                print("✅ Claude API success: \(claudeData)")
                return ReceiptData(
                    amount: claudeData.amount,
                    categoryName: claudeData.category,
                    fullText: fallbackText,
                    confidence: determineConfidence(
                        hasAmount: claudeData.amount != nil,
                        hasCategory: claudeData.category != nil
                    ),
                    ocrSource: .claude
                )
            }

        } catch {
            print("❌ Claude API network error: \(error.localizedDescription)")
        }

        return fallbackData(fallbackText)
    }

    /// Parse della response di Claude
    /// - Parameter data: JSON response
    /// - Returns: Amount e category estratti
    private func parseClaudeResponse(_ data: Data) -> (amount: Double?, category: String?)? {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstContent = content.first,
                  let text = firstContent["text"] as? String else {
                return nil
            }

            // Estrai JSON dalla risposta di Claude
            // Claude potrebbe rispondere con: {"amount": 45.50, "category": "Supermarket"}
            guard let jsonData = text.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }

            let amount = parsed["amount"] as? Double
            let category = parsed["category"] as? String

            return (amount, category)

        } catch {
            print("⚠️ Error parsing Claude response: \(error)")
            return nil
        }
    }

    /// Ritorna dati fallback in caso di errore
    private func fallbackData(_ text: String) -> ReceiptData {
        return ReceiptData(
            amount: nil,
            categoryName: nil,
            fullText: text,
            confidence: .low,
            ocrSource: .appleVision
        )
    }
}
