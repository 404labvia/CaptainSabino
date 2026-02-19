//
//  ImageStorageService.swift
//  CaptainSabino
//
//  Servizio per salvataggio locale immagini scontrini e fatture.
//  Le immagini sono visibili in Files > On My iPhone > CaptainSabino > Receipts/ o Invoices/
//

import UIKit

final class ImageStorageService {
    static let shared = ImageStorageService()

    private init() {
        createDirectoriesIfNeeded()
    }

    // MARK: - Directories

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Cartella in base al tipo di inserimento (Receipts per scontrini, Invoices per fatture)
    func directory(for entryType: EntryType) -> URL {
        switch entryType {
        case .invoice:
            return documentsDirectory.appendingPathComponent("Invoices", isDirectory: true)
        default:
            return documentsDirectory.appendingPathComponent("Receipts", isDirectory: true)
        }
    }

    private func createDirectoriesIfNeeded() {
        for dir in [directory(for: .receipt), directory(for: .invoice)] {
            if !FileManager.default.fileExists(atPath: dir.path) {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Public API

    /// Salva UIImage come JPEG (max 200 KB) e ritorna il filename semantico
    /// Formato: `20260219_150,50€_Fuel_ENI.jpg`
    @discardableResult
    func saveImage(
        _ image: UIImage,
        date: Date,
        amount: Double,
        categoryName: String,
        merchantName: String,
        entryType: EntryType
    ) throws -> String {
        let filename = buildFilename(date: date, amount: amount, category: categoryName, merchant: merchantName)
        let fileURL = directory(for: entryType).appendingPathComponent(filename)

        guard let data = compressedJPEG(image) else {
            throw ImageStorageError.compressionFailed
        }

        try data.write(to: fileURL, options: .atomic)
        return filename
    }

    // MARK: - Filename

    private func buildFilename(date: Date, amount: Double, category: String, merchant: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let dateStr = df.string(from: date)

        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "it_IT")
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        let amountStr = (nf.string(from: NSNumber(value: amount)) ?? "\(amount)") + "€"

        let catStr = sanitizeFilenameComponent(category)
        let merchantStr = String(sanitizeFilenameComponent(merchant).prefix(20))

        return "\(dateStr)_\(amountStr)_\(catStr)_\(merchantStr).jpg"
    }

    private func sanitizeFilenameComponent(_ s: String) -> String {
        let sanitized = s.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        // Rimuovi underscore multipli consecutivi
        var result = sanitized
        while result.contains("__") {
            result = result.replacingOccurrences(of: "__", with: "_")
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    /// Carica UIImage dal filename e dal tipo di entrata
    func loadImage(filename: String, entryType: EntryType) -> UIImage? {
        let fileURL = directory(for: entryType).appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Elimina immagine dal disco
    func deleteImage(filename: String, entryType: EntryType) {
        let fileURL = directory(for: entryType).appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Spazio totale occupato da Receipts + Invoices
    func totalStorageUsed() -> Int64 {
        let dirs = [directory(for: .receipt), directory(for: .invoice)]
        return dirs.reduce(0) { total, dir in
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey]
            ) else { return total }
            return total + contents.reduce(0) { t, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return t + Int64(size)
            }
        }
    }

    // MARK: - Compression

    /// Comprime iterativamente fino a max 200 KB (204.800 bytes)
    private func compressedJPEG(_ image: UIImage, maxBytes: Int = 204_800) -> Data? {
        var quality: CGFloat = 0.75
        while quality >= 0.1 {
            if let data = image.jpegData(compressionQuality: quality),
               data.count <= maxBytes {
                return data
            }
            quality -= 0.1
        }
        // Ultimo tentativo a qualità minima
        return image.jpegData(compressionQuality: 0.05)
    }
}

// MARK: - Errors

enum ImageStorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image for storage."
        }
    }
}
