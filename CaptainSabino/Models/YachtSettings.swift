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
    var id: UUID

    /// Nome dello yacht
    var yachtName: String

    /// Email dell'armatore/destinatario report
    var ownerEmail: String

    /// Nome del comandante
    var captainName: String

    /// Email del comandante (mittente report)
    var captainEmail: String

    /// Data di creazione/configurazione iniziale
    var createdAt: Date

    /// Data ultimo aggiornamento
    var updatedAt: Date

    // MARK: - Initializer

    /// Inizializzatore per creare le impostazioni
    /// - Parameters:
    ///   - yachtName: Nome dello yacht
    ///   - ownerEmail: Email armatore (destinatario)
    ///   - captainName: Nome comandante
    ///   - captainEmail: Email comandante (mittente)
    init(
        yachtName: String = "",
        ownerEmail: String = "",
        captainName: String = "",
        captainEmail: String = ""
    ) {
        self.id = UUID()
        self.yachtName = yachtName
        self.ownerEmail = ownerEmail
        self.captainName = captainName
        self.captainEmail = captainEmail
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
        return !yachtName.isEmpty &&
               !ownerEmail.isEmpty &&
               !captainName.isEmpty &&
               !captainEmail.isEmpty &&
               ownerEmail.contains("@") &&
               captainEmail.contains("@")
    }
}

// MARK: - Extension per Sample Data

extension YachtSettings {
    /// Dati di esempio per Preview
    static var sample: YachtSettings {
        return YachtSettings(
            yachtName: "Azure Dream",
            ownerEmail: "owner@example.com",
            captainName: "Marco Bianchi",
            captainEmail: "captain@example.com"
        )
    }
}
