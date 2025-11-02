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
    
    /// Nome dell'armatore/proprietario
    var ownerName: String
    
    /// Email dell'armatore (preimpostata per report)
    var ownerEmail: String
    
    /// Nome del comandante
    var captainName: String
    
    /// Tasso di cambio fisso EUR/USD (es: 1.10)
    var exchangeRateEURtoUSD: Double
    
    /// Data di creazione/configurazione iniziale
    var createdAt: Date
    
    /// Data ultimo aggiornamento
    var updatedAt: Date
    
    // MARK: - Initializer
    
    /// Inizializzatore per creare le impostazioni
    /// - Parameters:
    ///   - yachtName: Nome dello yacht
    ///   - ownerName: Nome armatore
    ///   - ownerEmail: Email armatore
    ///   - captainName: Nome comandante
    ///   - exchangeRate: Tasso cambio EUR/USD (default: 1.10)
    init(
        yachtName: String = "",
        ownerName: String = "",
        ownerEmail: String = "",
        captainName: String = "",
        exchangeRate: Double = 1.10
    ) {
        self.id = UUID()
        self.yachtName = yachtName
        self.ownerName = ownerName
        self.ownerEmail = ownerEmail
        self.captainName = captainName
        self.exchangeRateEURtoUSD = exchangeRate
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
               !ownerName.isEmpty &&
               !ownerEmail.isEmpty &&
               !captainName.isEmpty &&
               ownerEmail.contains("@")
    }
}

// MARK: - Extension per Sample Data

extension YachtSettings {
    /// Dati di esempio per Preview
    static var sample: YachtSettings {
        return YachtSettings(
            yachtName: "Azure Dream",
            ownerName: "Alessandro Rossi",
            ownerEmail: "alessandro.rossi@example.com",
            captainName: "Marco Bianchi",
            exchangeRate: 1.10
        )
    }
}
