//
//  ImageStorageService.swift
//  CaptainSabino
//
//  Servizio per salvataggio locale immagini scontrini e fatture
//

import UIKit

final class ImageStorageService {
    static let shared = ImageStorageService()

    private init() {
        createReceiptsDirectoryIfNeeded()
    }

    // MARK: - Directory

    /// Directory locale per le immagini: Library/Application Support/Receipts/
    private var receiptsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Receipts", isDirectory: true)
    }

    private func createReceiptsDirectoryIfNeeded() {
        let dir = receiptsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    /// Salva UIImage come JPEG e ritorna il filename (es. "UUID.jpg")
    @discardableResult
    func saveImage(_ image: UIImage, expenseID: UUID) throws -> String {
        let filename = "\(expenseID.uuidString).jpg"
        let fileURL = receiptsDirectory.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.75) else {
            throw ImageStorageError.compressionFailed
        }

        try data.write(to: fileURL, options: .atomic)
        return filename
    }

    /// Carica UIImage dal filename salvato in Expense.receiptImagePath
    func loadImage(filename: String) -> UIImage? {
        let fileURL = receiptsDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// Elimina immagine dal disco (chiamare quando si elimina una spesa)
    func deleteImage(filename: String) {
        let fileURL = receiptsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Calcola spazio totale occupato dalle immagini scontrini
    func totalStorageUsed() -> Int64 {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: receiptsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
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
