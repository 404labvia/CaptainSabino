//
//  ReceiptStorageService.swift
//  CaptainSabino
//
//  Servizio per gestire il salvataggio e recupero delle foto degli scontrini
//

import Foundation
import UIKit
import SwiftData

class ReceiptStorageService {
    // MARK: - Singleton

    static let shared = ReceiptStorageService()

    private init() {
        setupReceiptsDirectory()
    }

    // MARK: - Constants

    private let receiptsFolder = "Receipts"
    private let imageQuality: CGFloat = 0.4 // Compressione aggressiva (scontrini = testo)
    private let maxImageWidth: CGFloat = 1200 // Risoluzione sufficiente per OCR

    // MARK: - Directory Management

    /// Ottiene l'URL della directory Receipts (locale o iCloud)
    /// - Parameter useICloud: Se true, usa iCloud Drive, altrimenti Documents locale
    private func getReceiptsDirectory(useICloud: Bool) -> URL? {
        if useICloud {
            // iCloud Drive container
            guard let iCloudURL = FileManager.default.url(
                forUbiquityContainerIdentifier: nil
            )?
                .appendingPathComponent("Documents")
                .appendingPathComponent(receiptsFolder) else {
                print("⚠️ iCloud container non disponibile")
                return nil
            }
            return iCloudURL
        } else {
            // Locale Documents
            guard let documentsURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
                print("⚠️ Documents directory non disponibile")
                return nil
            }
            return documentsURL.appendingPathComponent(receiptsFolder)
        }
    }

    /// Crea la directory Receipts se non esiste
    private func setupReceiptsDirectory() {
        // Setup locale (sempre necessario)
        if let localDir = getReceiptsDirectory(useICloud: false) {
            try? FileManager.default.createDirectory(
                at: localDir,
                withIntermediateDirectories: true
            )
        }

        // Setup iCloud (se disponibile)
        if let iCloudDir = getReceiptsDirectory(useICloud: true) {
            try? FileManager.default.createDirectory(
                at: iCloudDir,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - Naming Convention

    /// Genera il nome file per uno scontrino
    /// Formato: 2025-07-23_154530_45.50€_Supermarket.jpg
    /// - Parameters:
    ///   - date: Data della spesa
    ///   - amount: Importo
    ///   - categoryName: Nome categoria
    /// - Returns: Nome file sanitizzato
    private func generateFileName(
        date: Date,
        amount: Double,
        categoryName: String
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: date)

        let amountString = String(format: "%.2f€", amount)
            .replacingOccurrences(of: ".", with: ",") // Formato europeo

        // Sanitizza nome categoria (rimuovi caratteri non validi per filesystem)
        let sanitizedCategory = categoryName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")

        return "\(dateString)_\(amountString)_\(sanitizedCategory).jpg"
    }

    // MARK: - Image Processing

    /// Ridimensiona l'immagine se troppo grande
    /// - Parameter image: Immagine originale
    /// - Returns: Immagine ottimizzata
    private func resizeImage(_ image: UIImage) -> UIImage {
        let width = image.size.width

        // Se già piccola abbastanza, ritorna originale
        if width <= maxImageWidth {
            return image
        }

        // Calcola nuove dimensioni mantenendo aspect ratio
        let scaleFactor = maxImageWidth / width
        let newHeight = image.size.height * scaleFactor
        let newSize = CGSize(width: maxImageWidth, height: newHeight)

        // Ridimensiona
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    // MARK: - Public Methods

    /// Salva la foto di uno scontrino
    /// - Parameters:
    ///   - image: Immagine dello scontrino
    ///   - date: Data della spesa
    ///   - amount: Importo
    ///   - categoryName: Nome categoria
    ///   - useICloud: Se sincronizzare su iCloud
    /// - Returns: Percorso relativo del file salvato, nil se errore
    func saveReceipt(
        image: UIImage,
        date: Date,
        amount: Double,
        categoryName: String,
        useICloud: Bool
    ) -> String? {
        // Genera nome file
        let fileName = generateFileName(
            date: date,
            amount: amount,
            categoryName: categoryName
        )

        // Ottimizza immagine
        let optimizedImage = resizeImage(image)

        // Converti in JPEG data
        guard let imageData = optimizedImage.jpegData(compressionQuality: imageQuality) else {
            print("⚠️ Impossibile convertire immagine in JPEG")
            return nil
        }

        // Ottieni directory di destinazione
        guard let receiptsDir = getReceiptsDirectory(useICloud: useICloud) else {
            print("⚠️ Directory receipts non disponibile")
            return nil
        }

        let fileURL = receiptsDir.appendingPathComponent(fileName)

        // Salva file
        do {
            try imageData.write(to: fileURL)
            print("✅ Scontrino salvato: \(fileName)")

            // Ritorna percorso relativo (solo nome file + useICloud flag)
            return useICloud ? "icloud:\(fileName)" : "local:\(fileName)"
        } catch {
            print("❌ Errore salvataggio scontrino: \(error.localizedDescription)")
            return nil
        }
    }

    /// Carica la foto di uno scontrino
    /// - Parameter path: Percorso relativo (formato: "icloud:filename" o "local:filename")
    /// - Returns: UIImage se trovata, nil altrimenti
    func loadReceipt(path: String) -> UIImage? {
        // Parse path
        let components = path.split(separator: ":")
        guard components.count == 2 else {
            print("⚠️ Formato path non valido: \(path)")
            return nil
        }

        let storageType = String(components[0])
        let fileName = String(components[1])
        let useICloud = (storageType == "icloud")

        // Ottieni directory
        guard let receiptsDir = getReceiptsDirectory(useICloud: useICloud) else {
            return nil
        }

        let fileURL = receiptsDir.appendingPathComponent(fileName)

        // Carica immagine
        do {
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch {
            print("⚠️ Impossibile caricare scontrino: \(error.localizedDescription)")
            return nil
        }
    }

    /// Elimina la foto di uno scontrino
    /// - Parameter path: Percorso relativo
    func deleteReceipt(path: String) {
        // Parse path
        let components = path.split(separator: ":")
        guard components.count == 2 else { return }

        let storageType = String(components[0])
        let fileName = String(components[1])
        let useICloud = (storageType == "icloud")

        // Ottieni directory
        guard let receiptsDir = getReceiptsDirectory(useICloud: useICloud) else {
            return
        }

        let fileURL = receiptsDir.appendingPathComponent(fileName)

        // Elimina file
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ Scontrino eliminato: \(fileName)")
    }

    /// Calcola lo spazio totale occupato dalle foto degli scontrini
    /// - Parameter useICloud: Se controllare iCloud o locale
    /// - Returns: Bytes totali occupati
    func getStorageUsed(useICloud: Bool) -> Int64 {
        guard let receiptsDir = getReceiptsDirectory(useICloud: useICloud) else {
            return 0
        }

        var totalSize: Int64 = 0

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: receiptsDir,
                includingPropertiesForKeys: [.fileSizeKey]
            )

            for file in files {
                if file.pathExtension == "jpg" {
                    let fileSize = try file.resourceValues(forKeys: [.fileSizeKey])
                    totalSize += Int64(fileSize.fileSize ?? 0)
                }
            }
        } catch {
            print("⚠️ Errore calcolo storage: \(error.localizedDescription)")
        }

        return totalSize
    }

    /// Migra le foto da locale a iCloud o viceversa
    /// - Parameter toICloud: true per migrare a iCloud, false per locale
    func migrateReceipts(toICloud: Bool) {
        let sourceDir = getReceiptsDirectory(useICloud: !toICloud)
        let destDir = getReceiptsDirectory(useICloud: toICloud)

        guard let source = sourceDir, let dest = destDir else {
            print("⚠️ Directory non disponibili per migrazione")
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: source,
                includingPropertiesForKeys: nil
            )

            var migratedCount = 0

            for file in files where file.pathExtension == "jpg" {
                let destURL = dest.appendingPathComponent(file.lastPathComponent)

                // Copia file
                try? FileManager.default.copyItem(at: file, to: destURL)

                // Elimina originale dopo copia riuscita
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try? FileManager.default.removeItem(at: file)
                    migratedCount += 1
                }
            }

            print("✅ Migrati \(migratedCount) scontrini verso \(toICloud ? "iCloud" : "locale")")
        } catch {
            print("❌ Errore migrazione: \(error.localizedDescription)")
        }
    }

    /// Elimina tutte le foto degli scontrini
    /// - Parameter includeICloud: Se eliminare anche da iCloud
    func deleteAllReceipts(includeICloud: Bool) {
        // Elimina locale
        if let localDir = getReceiptsDirectory(useICloud: false) {
            try? FileManager.default.removeItem(at: localDir)
            setupReceiptsDirectory() // Ricrea directory vuota
        }

        // Elimina iCloud se richiesto
        if includeICloud, let iCloudDir = getReceiptsDirectory(useICloud: true) {
            try? FileManager.default.removeItem(at: iCloudDir)
            setupReceiptsDirectory()
        }

        print("🗑️ Tutti gli scontrini eliminati")
    }
}

// MARK: - Helper Extensions

extension Int64 {
    /// Formatta i bytes in formato human-readable (KB, MB, GB)
    var formattedByteSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
