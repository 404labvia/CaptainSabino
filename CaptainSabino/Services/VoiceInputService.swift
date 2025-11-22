//
//  VoiceInputService.swift
//  CaptainSabino
//
//  Servizio per riconoscimento vocale e parsing delle spese
//

import Foundation
import Speech
import AVFoundation

class VoiceInputService: ObservableObject {
    // MARK: - Singleton

    static let shared = VoiceInputService()
    private init() {}

    // MARK: - Properties

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Authorization

    /// Richiede i permessi per speech recognition e microfono
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                completion(status == .authorized)
            }
        }
    }

    /// Verifica se i permessi sono stati concessi
    func checkAuthorization() -> Bool {
        return authorizationStatus == .authorized
    }

    // MARK: - Recording

    /// Inizia la registrazione e il riconoscimento vocale
    func startRecording() throws {
        // Cancella task precedente se esiste
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        // Configura audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Crea recognizer per italiano
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))

        // Crea recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceInputService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        // Input node
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil

                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }

        // Audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        DispatchQueue.main.async {
            self.isRecording = true
            self.transcribedText = ""
        }
    }

    /// Ferma la registrazione
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()

        if let inputNode = audioEngine.inputNode as AVAudioInputNode? {
            inputNode.removeTap(onBus: 0)
        }

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    // MARK: - Text Parsing

    /// Estrae importo e categoria dal testo trascritto
    func parseExpenseFromText(_ text: String) -> (amount: Double?, categoryName: String?) {
        let lowercased = text.lowercased()

        // Estrai importo
        let amount = extractAmount(from: lowercased)

        // Estrai categoria
        let category = extractCategory(from: lowercased)

        return (amount, category)
    }

    /// Estrae l'importo dal testo
    private func extractAmount(from text: String) -> Double? {
        // Pattern per numeri: "20", "20.50", "20,50"
        let numberPattern = #"(\d+[,.]?\d*)"#

        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text) {
                let numberString = String(text[range]).replacingOccurrences(of: ",", with: ".")
                return Double(numberString)
            }
        }

        // Numeri in lettere italiane (opzionale - per versioni future)
        let wordNumbers: [String: Double] = [
            "zero": 0, "uno": 1, "due": 2, "tre": 3, "quattro": 4, "cinque": 5,
            "sei": 6, "sette": 7, "otto": 8, "nove": 9, "dieci": 10,
            "venti": 20, "trenta": 30, "quaranta": 40, "cinquanta": 50,
            "sessanta": 60, "settanta": 70, "ottanta": 80, "novanta": 90,
            "cento": 100, "duecento": 200, "trecento": 300, "quattrocento": 400, "cinquecento": 500
        ]

        for (word, value) in wordNumbers {
            if text.contains(word) {
                return value
            }
        }

        return nil
    }

    /// Estrae la categoria dal testo basandosi su parole chiave
    private func extractCategory(from text: String) -> String? {
        // Mapping parole chiave → categoria
        let categoryKeywords: [(keywords: [String], category: String)] = [
            (["cibo", "food", "ristorante", "mangiare", "pranzo", "cena", "colazione"], "Food"),
            (["carburante", "fuel", "benzina", "gasolio", "diesel"], "Fuel"),
            (["farmacia", "pharmacy", "medicine", "medicinale"], "Pharmacy"),
            (["equipaggio", "crew", "marinaio"], "Crew"),
            (["chandlery", "attrezzatura", "ricambi"], "Chandlery"),
            (["water test", "test acqua", "analisi acqua"], "Water Test"),
            (["saldatura", "welder", "saldatore"], "Welder"),
            (["tender fuel", "carburante tender"], "Tender Fuel"),
            (["volo", "fly", "aereo", "biglietto"], "Fly")
        ]

        for item in categoryKeywords {
            for keyword in item.keywords {
                if text.contains(keyword) {
                    return item.category
                }
            }
        }

        return nil
    }
}
