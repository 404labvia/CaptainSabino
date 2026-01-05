//
//  InvoicePDFPickerView.swift
//  CaptainSabino
//
//  View per selezionare file PDF di fatture
//

import SwiftUI
import UniformTypeIdentifiers

struct InvoicePDFPickerView: UIViewControllerRepresentable {

    // MARK: - Properties

    let onPDFSelected: (URL) -> Void
    let onCancel: () -> Void

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPDFSelected: onPDFSelected, onCancel: onCancel)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPDFSelected: (URL) -> Void
        let onCancel: () -> Void

        init(onPDFSelected: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPDFSelected = onPDFSelected
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Could not access security-scoped resource")
                onCancel()
                return
            }

            // Copy file to temporary location for processing
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                url.stopAccessingSecurityScopedResource()
                onPDFSelected(tempURL)
            } catch {
                print("❌ Error copying PDF: \(error)")
                url.stopAccessingSecurityScopedResource()
                onCancel()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Preview

#Preview {
    InvoicePDFPickerView(
        onPDFSelected: { url in
            print("Selected: \(url)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
