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

enum CategoryMatchStrength {
    case strong  // Score >= 20 (keyword specifiche tipo "ENI", "CONAD")
    case weak    // Score 1-19 (keyword generiche tipo "BAR")
    case none    // Score = 0 (nessun match)
}

struct CategoryMatch {
    var categoryName: String?
    var score: Int
    var strength: CategoryMatchStrength
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
            // Italia - grandi catene
            "CONAD", "COOP", "ESSELUNGA", "CARREFOUR", "EUROSPIN",
            "LIDL", "MD", "PENNY", "ALDI", "AUCHAN", "SIMPLY",
            "PAM", "SIGMA", "FAMILA", "BENNET", "IPER", "IPERAL",
            "TODIS", "TUODI", "IN'S", "DESPAR", "SPAR", "INTERSPAR",
            "IL GIGANTE", "GIGANTE", "PRIX", "U2", "DECO'",
            "TIGRE", "TIGROS", "DOK", "CADORO", "POLI",
            "OASI", "ALI'", "ALIPER", "DIMEGLIO", "SIDIS",
            // Mini market e discount
            "MINIMARKET", "ALIMENTARI", "DISCOUNT", "MARKET",
            // Francia
            "LECLERC", "INTERMARCHE", "MONOPRIX", "FRANPRIX", "CASINO",
            // Spagna
            "MERCADONA", "DIA", "ALCAMPO", "CARREFOUR EXPRESS",
            // Germania
            "REWE", "EDEKA", "KAUFLAND", "NETTO", "NORMA",
            // UK
            "TESCO", "SAINSBURY", "ASDA", "MORRISONS", "WAITROSE",
            // Generici
            "SUPERMARKET", "SUPERMERCATO", "SUPERMARKT", "GROCERY", "GROCERIES"
        ],

        "Fuel": [
            // Brand Italia - principali
            "ENI", "AGIP", "Q8", "TAMOIL", "IP", "ESSO", "SHELL",
            "ERG", "TOTALERG", "API", "ITALGAS", "PETRONAS",
            "POMPE BIANCHE", "SELF SERVICE", "SELF 24",
            // Brand internazionali
            "BP", "TOTAL", "REPSOL", "CEPSA", "GALP",
            "GULF", "TEXACO", "MOBIL", "KUWAIT", "LUKOIL",
            "AVIA", "JET", "ARAL", "OMV", "MOL",
            // Parole su scontrini carburante
            "CARBURANTE", "BENZINA", "DIESEL", "GASOLIO", "GPL",
            "RIFORNIMENTO", "FUEL", "PETROL", "GASOLINE", "GAS",
            "STATION", "DISTRIBUTORE", "STAZIONE SERVIZIO",
            "LITRI", "LITER", "LITERS", "LT", "SELF", "SERVITO"
        ],

        "Pharmacy": [
            "FARMACIA", "PHARMACY", "APOTHEKE", "APOTEK", "PHARMACIE",
            "DROGUERIE", "LLOYDS", "BOOTS", "PARAFARMACIA",
            "FARMACIE", "APOTEKA"
        ],

        "Food": [
            // Ristoranti italiani
            "RISTORANTE", "TRATTORIA", "PIZZERIA", "OSTERIA", "TAVERNA",
            "LOCANDA", "AGRITURISMO", "TAVOLA CALDA", "ROSTICCERIA",
            "PANINOTECA", "BRACERIA", "PESCHERIA", "ENOTECA",
            // Bar e caffè
            "BAR", "CAFFE", "CAFFETTERIA", "PASTICCERIA", "GELATERIA",
            "LATTERIA", "SALUMERIA", "FORNO", "PANIFICIO", "PANETTERIA",
            // Parole sugli scontrini di ristoranti/bar
            "COPERTO", "SERVIZIO", "TAVOLO", "COPERTI", "MENU", "MENÙ",
            "CAMERIERE", "RICEVUTA FISCALE", "SCONTRINO FISCALE",
            // Tipologie ristorazione
            "STREET FOOD", "FAST FOOD", "SELF SERVICE", "BUFFET",
            // Internazionali comuni
            "RESTAURANT", "CAFETERIA", "CAFE", "BISTRO", "BRASSERIE",
            "PUB", "GASTHAUS", "TAVOLA", "CUCINA", "GRILL",
            // Catene fast food
            "MCDONALD", "MCDONALDS", "BURGER KING", "KFC", "SUBWAY",
            "AUTOGRILL", "ROADHOUSE", "OLD WILD WEST", "CIGIERRE",
            // Tipi di locali
            "COCKTAIL BAR", "WINE BAR", "LOUNGE", "SNACK BAR",
            "BEACH BAR", "RISTOBAR", "BACARO"
        ],

        "Chandlery": [
            // Forniture nautiche
            "CHANDLER", "CHANDLERY", "NAUTICA", "MARINE", "MARINERIA",
            "SHIP CHANDLER", "SHIP SUPPLIER", "FORNITURE NAVALI",
            // Termini nautici
            "YACHT", "BOAT", "BARCA", "IMBARCAZIONE", "NAVE",
            "SHIP", "SAILING", "VELA", "MOTOR", "MOTORE",
            // Luoghi nautici
            "CANTIERE", "SHIPYARD", "BOATYARD", "MARINA",
            "PORTO", "PORT", "HARBOUR", "HARBOR", "DOCK",
            // Prodotti nautici comuni
            "VELERIA", "SAILMAKER", "CORDAME", "ROPE", "CIMA",
            "ANCORA", "ANCHOR", "CATENA", "CHAIN",
            "VERNICE", "ANTIVEGETATIVA", "ANTIFOULING", "PAINT",
            "PARABORDO", "FENDER", "SALVAGENTE", "LIFE JACKET",
            // Termini generici
            "NAVALE", "MARITIME", "MARITTIMO", "DIPORTO",
            "ACCESSORIES MARINE", "RICAMBI NAUTICI"
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
    ///   - learnedKeywords: Keyword apprese dal sistema (opzionale)
    /// - Returns: ReceiptData con informazioni estratte
    func processReceipt(
        image: UIImage,
        claudeAPIKey: String? = nil,
        learnedKeywords: [LearnedKeyword] = []
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

        // Step 3: Keyword matching per categoria (base + learned)
        print("📊 Matching with \(categoryKeywords.count) base categories + \(learnedKeywords.count) learned keywords")
        let categoryMatch = matchCategory(from: visionText, learnedKeywords: learnedKeywords)

        // Step 4: Determina se serve Claude API (THRESHOLD LOGIC)
        let shouldUseClaude: Bool

        if extractedAmount == nil {
            // SEMPRE usare Claude se amount non trovato
            shouldUseClaude = true
            print("🔄 Amount not found → Claude needed")
        } else if categoryMatch.strength == .strong {
            // STRONG match + amount trovato = NON serve Claude
            shouldUseClaude = false
            print("✅ Strong category match + amount found → Claude NOT needed")
        } else {
            // WEAK o NO match = usare Claude per conferma categoria
            shouldUseClaude = true
            print("🔄 Weak/no category match → Claude needed")
        }

        // Step 5: Usa Claude se necessario E se API key disponibile
        if shouldUseClaude, let apiKey = claudeAPIKey, !apiKey.isEmpty {
            print("📞 Calling Claude API...")
            return await processWithClaudeAPI(
                image: image,
                apiKey: apiKey,
                fallbackText: visionText
            )
        }

        // Step 6: Determina confidence del risultato Apple Vision
        let confidence = determineConfidence(
            hasAmount: extractedAmount != nil,
            hasCategory: categoryMatch.categoryName != nil
        )

        // Ritorna risultato Apple Vision + Keywords (senza Claude)
        return ReceiptData(
            amount: extractedAmount,
            categoryName: categoryMatch.categoryName,
            fullText: visionText,
            confidence: confidence,
            ocrSource: categoryMatch.categoryName != nil ? .hybrid : .appleVision
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

    /// Estrae parole chiave significative dal nome del merchant (prime righe scontrino)
    /// - Parameter text: Testo OCR completo
    /// - Returns: Array di keyword da apprendere (max 5, >3 caratteri)
    func extractMerchantKeywords(from text: String) -> [String] {
        // Parole generiche da escludere (troppo comuni)
        let commonWords: Set<String> = [
            "S.P.A", "SPA", "S.R.L", "SRL", "S.N.C", "SNC", "S.A.S", "SAS",
            "VIA", "VIALE", "PIAZZA", "CORSO", "STRADA", "LARGO",
            "P.IVA", "PIVA", "C.F.", "TEL", "FAX", "WWW", "HTTP",
            "ITALY", "ITALIA", "FISCALE", "CODICE", "PARTITA",
            "RICEVUTA", "SCONTRINO", "RECEIPT", "FATTURA",
            "DATA", "DATE", "ORA", "TIME", "NUMERO", "NUMBER"
        ]

        let lines = text.split(separator: "\n")

        // Prendi le prime 3 righe (di solito nome merchant)
        let topLines = Array(lines.prefix(3))

        var keywords: [String] = []

        for line in topLines {
            let words = line.split(separator: " ")

            for word in words {
                let cleanWord = String(word)
                    .uppercased()
                    .trimmingCharacters(in: CharacterSet.punctuationCharacters)

                // Filtra parole significative
                let isValidLength = cleanWord.count >= 4  // Min 4 caratteri
                let isNotNumber = !cleanWord.allSatisfy { $0.isNumber }
                let isNotCommon = !commonWords.contains(cleanWord)
                let hasLetters = cleanWord.contains { $0.isLetter }

                if isValidLength && isNotNumber && isNotCommon && hasLetters {
                    keywords.append(cleanWord)
                }
            }
        }

        // Rimuovi duplicati e limita a 5
        let uniqueKeywords = Array(Set(keywords)).prefix(5)

        print("📚 Extracted keywords for learning: \(uniqueKeywords.joined(separator: ", "))")

        return Array(uniqueKeywords)
    }

    /// Trova la categoria più probabile dal testo con score
    /// - Parameters:
    ///   - text: Testo OCR
    ///   - learnedKeywords: Keyword apprese dal sistema (opzionale)
    /// - Returns: CategoryMatch con categoria, score e strength
    private func matchCategory(from text: String, learnedKeywords: [LearnedKeyword] = []) -> CategoryMatch {
        let normalizedText = text.uppercased()

        var categoryScores: [String: Int] = [:]

        // PARTE 1: Cerca keyword BASE (hard-coded)
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

        // PARTE 2: Cerca keyword LEARNED (apprese dall'utente)
        for learned in learnedKeywords {
            if normalizedText.contains(learned.keyword) {
                // Peso keyword learned: lunghezza + bonus per usage count
                let baseScore = learned.keyword.count
                let usageBonus = min(learned.usageCount, 5) // Max +5 bonus
                let totalScore = baseScore + usageBonus

                categoryScores[learned.categoryName, default: 0] += totalScore

                print("🎯 Learned keyword matched: '\(learned.keyword)' → \(learned.categoryName) (+\(totalScore) points, used \(learned.usageCount) times)")
            }
        }

        // Trova categoria con score più alto
        if let bestMatch = categoryScores.max(by: { $0.value < $1.value }) {
            let score = bestMatch.value

            // Determina strength del match
            let strength: CategoryMatchStrength
            if score >= 20 {
                strength = .strong
                print("✅ STRONG match: \(bestMatch.key) (score: \(score)) - no Claude needed")
            } else {
                strength = .weak
                print("⚠️ WEAK match: \(bestMatch.key) (score: \(score)) - Claude recommended")
            }

            return CategoryMatch(
                categoryName: bestMatch.key,
                score: score,
                strength: strength
            )
        }

        print("⚠️ NO match - Claude needed")
        return CategoryMatch(
            categoryName: nil,
            score: 0,
            strength: .none
        )
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

    /// Ridimensiona l'immagine per Claude API (max 5 MB)
    /// - Parameter image: Immagine originale
    /// - Returns: Immagine ridimensionata
    private func resizeImageForClaude(_ image: UIImage) -> UIImage {
        let maxWidth: CGFloat = 1200 // Stessa dimensione di ReceiptStorageService
        let width = image.size.width

        // Se già piccola abbastanza, ritorna originale
        if width <= maxWidth {
            return image
        }

        // Calcola nuove dimensioni mantenendo aspect ratio
        let scaleFactor = maxWidth / width
        let newHeight = image.size.height * scaleFactor
        let newSize = CGSize(width: maxWidth, height: newHeight)

        // Ridimensiona
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

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

        // Ridimensiona immagine per rispettare limite 5 MB di Claude API
        let resizedImage = resizeImageForClaude(image)

        guard let imageData = resizedImage.jpegData(compressionQuality: 0.6) else {
            return ReceiptData(
                amount: nil,
                categoryName: nil,
                fullText: fallbackText,
                confidence: .low,
                ocrSource: .appleVision
            )
        }

        let imageSizeMB = Double(imageData.count) / 1_048_576.0
        print("📏 Image size for Claude: \(String(format: "%.2f", imageSizeMB)) MB (\(imageData.count) bytes)")

        let base64Image = imageData.base64EncodedString()

        // Costruisci request body
        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",  // Claude 4.5 Haiku - Best accuracy
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
                            Extract the TOTAL PAID AMOUNT (in euros) and CATEGORY from this receipt image.

                            AMOUNT EXTRACTION:
                            - Look for: "PAGATO", "CARTA", "CONTANTI", "BANCOMAT", "TOTALE" (NOT "SUBTOTALE")
                            - This is the final amount paid INCLUDING tax/IVA
                            - Format: just the number (e.g., 45.50)

                            CATEGORY CLASSIFICATION:
                            Classify into ONE of these EXACT categories based on merchant name, items, and context:

                            - "Food" → Restaurants, bars, pizzerias, cafes, trattorias. Look for: RISTORANTE, BAR, PIZZERIA, COPERTO, SERVIZIO, TAVOLO, CAMERIERE
                            - "Supermarket" → Grocery stores. Look for: CONAD, COOP, ESSELUNGA, CARREFOUR, LIDL, EUROSPIN, ALIMENTARI, MARKET
                            - "Fuel" → Gas stations. Look for: ENI, AGIP, Q8, SHELL, ESSO, TAMOIL, IP, CARBURANTE, BENZINA, DIESEL, LITRI
                            - "Chandlery" → Marine supplies, yacht equipment. Look for: NAUTICA, MARINE, SHIP CHANDLER, CANTIERE, VELERIA, ANCORA, PARABORDO
                            - "Pharmacy" → Pharmacies and drugstores. Look for: FARMACIA, PHARMACY, PARAFARMACIA
                            - "Water Test" → Water analysis labs. Look for: WATER TEST, ANALISI, LABORATORIO, TEST ACQUA
                            - "Welder" → Welding services, metalwork. Look for: SALDATURE, WELDING, CARPENTERIA
                            - "Tender Fuel" → Dinghy/tender fuel. Look for: TENDER, GOMMONE, DINGHY
                            - "Fly" → Airports, airlines. Look for: AIRPORT, AEROPORTO, AIRLINE, FLIGHT, VOLO
                            - "Crew" → Crew salaries and payroll. Look for: SALARY, STIPENDIO, CREW, EQUIPAGGIO

                            Reply ONLY with JSON format (no additional text):
                            {"amount": 45.50, "category": "Food"}

                            If you cannot determine amount or category, use null:
                            {"amount": null, "category": "Supermarket"}
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

            print("🔄 Calling Claude API...")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Claude API error: No HTTP response")
                return fallbackData(fallbackText)
            }

            print("📡 Claude API HTTP Status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                // Log error details
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("❌ Claude API error body: \(errorBody)")
                }
                return fallbackData(fallbackText)
            }

            // Log raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("📄 Claude API raw response: \(rawResponse)")
            }

            // Parse response
            if let claudeData = parseClaudeResponse(data) {
                print("✅ Claude API parsed - Amount: €\(claudeData.amount?.description ?? "nil"), Category: \(claudeData.category ?? "nil")")
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
            } else {
                print("❌ Claude API response parsing failed")
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
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("⚠️ Claude response: not a JSON object")
                return nil
            }

            guard let content = json["content"] as? [[String: Any]] else {
                print("⚠️ Claude response: no 'content' array")
                return nil
            }

            guard let firstContent = content.first else {
                print("⚠️ Claude response: content array is empty")
                return nil
            }

            guard let text = firstContent["text"] as? String else {
                print("⚠️ Claude response: no 'text' in content")
                return nil
            }

            print("📝 Claude extracted text: \(text)")

            // Estrai JSON dalla risposta di Claude
            // Claude potrebbe rispondere con: {"amount": 45.50, "category": "Supermarket"}
            guard let jsonData = text.data(using: .utf8) else {
                print("⚠️ Cannot convert Claude text to data")
                return nil
            }

            guard let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("⚠️ Claude text is not valid JSON: \(text)")
                return nil
            }

            let amount = parsed["amount"] as? Double
            let category = parsed["category"] as? String

            print("🔍 Parsed from Claude JSON - amount: \(amount?.description ?? "nil"), category: \(category ?? "nil")")

            return (amount, category)

        } catch {
            print("❌ Error parsing Claude response: \(error.localizedDescription)")
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
