//
//  YachtSettings.swift
//  YachtExpense
//
//  Modello per le impostazioni globali dell'app
//

import Foundation
import SwiftData

@Model
final class YachtSettings {
    // MARK: - Properties

    /// ID univoco (ci sarà solo 1 istanza)
    var id: UUID = UUID()

    /// Nome dello yacht
    var yachtName: String = ""

    /// Nome del comandante
    var captainName: String = ""

    /// Data di creazione/configurazione iniziale
    var createdAt: Date = Date()

    /// Data ultimo aggiornamento
    var updatedAt: Date = Date()

    /// Chiave API Claude (richiesta per OCR scontrini)
    var claudeAPIKey: String?

    // MARK: - Initializer

    /// Inizializzatore per creare le impostazioni
    /// - Parameters:
    ///   - yachtName: Nome dello yacht
    ///   - captainName: Nome comandante
    ///   - claudeAPIKey: Chiave API Claude opzionale (default: nil)
    init(
        yachtName: String = "",
        captainName: String = "",
        claudeAPIKey: String? = nil
    ) {
        self.id = UUID()
        self.yachtName = yachtName
        self.captainName = captainName
        self.claudeAPIKey = claudeAPIKey
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Methods

    /// Aggiorna la data di ultimo aggiornamento
    func touch() {
        self.updatedAt = Date()
    }

    /// Verifica se le impostazioni sono complete
    var isComplete: Bool {
        return !yachtName.isEmpty && !captainName.isEmpty
    }
}

// MARK: - Extension per Sample Data

extension YachtSettings {
    /// Dati di esempio per Preview
    static var sample: YachtSettings {
        return YachtSettings(
            yachtName: "Azure Dream",
            captainName: "Marco Bianchi"
        )
    }
}
