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
    private let imageQuality: CGFloat = 0.6
    private let maxImageWidth: CGFloat = 1200

    // MARK: - Directory Management

    private func getReceiptsDirectory() -> URL? {
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return documentsURL.appendingPathComponent(receiptsFolder)
    }

    private func setupReceiptsDirectory() {
        if let localDir = getReceiptsDirectory() {
            try? FileManager.default.createDirectory(
                at: localDir,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - Naming Convention

    private func generateFileName(
        date: Date,
        amount: Double,
        categoryName: String
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateString = dateFormatter.string(from: date)

        let amountString = String(format: "%.2f€", amount)
            .replacingOccurrences(of: ".", with: ",")

        let sanitizedCategory = categoryName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")

        return "\(dateString)_\(amountString)_\(sanitizedCategory).jpg"
    }

    // MARK: - Image Processing

    private func resizeImage(_ image: UIImage) -> UIImage {
        let width = image.size.width

        if width <= maxImageWidth {
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

    // MARK: - Public Methods

    func saveReceipt(
        image: UIImage,
        date: Date,
        amount: Double,
        categoryName: String
    ) -> String? {
        let fileName = generateFileName(
            date: date,
            amount: amount,
            categoryName: categoryName
        )

        let optimizedImage = resizeImage(image)

        guard let imageData = optimizedImage.jpegData(compressionQuality: imageQuality) else {
            return nil
        }

        guard let receiptsDir = getReceiptsDirectory() else {
            return nil
        }

        let fileURL = receiptsDir.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }

    func loadReceipt(fileName: String) -> UIImage? {
        guard let receiptsDir = getReceiptsDirectory() else {
            return nil
        }

        let fileURL = receiptsDir.appendingPathComponent(fileName)

        do {
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    func deleteReceipt(fileName: String) {
        guard let receiptsDir = getReceiptsDirectory() else {
            return
        }

        let fileURL = receiptsDir.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    func getStorageUsed() -> Int64 {
        guard let receiptsDir = getReceiptsDirectory() else {
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
            // Ignore errors
        }

        return totalSize
    }

    func deleteAllReceipts() {
        if let localDir = getReceiptsDirectory() {
            try? FileManager.default.removeItem(at: localDir)
            setupReceiptsDirectory()
        }
    }
}

// MARK: - Helper Extensions

extension Int64 {
    var formattedByteSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
