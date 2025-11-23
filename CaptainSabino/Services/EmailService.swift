//
//  EmailService.swift
//  YachtExpense
//
//  Servizio per invio email (UIKit bridge per MessageUI)
//

import Foundation
import SwiftUI
import MessageUI

// MARK: - MailView (SwiftUI Wrapper)

struct MailView: UIViewControllerRepresentable {
    let pdfURL: URL
    let recipientEmail: String
    let subject: String
    let yachtName: String
    let captainName: String

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = context.coordinator

        // Setup email
        mailVC.setToRecipients([recipientEmail])
        mailVC.setSubject(subject)

        // Body
        let body = """
        Dear Owner,

        Please find attached the expense report for \(yachtName).

        This report includes a detailed breakdown of all expenses for the selected period.

        Best regards,
        \(captainName)
        Captain
        """
        mailVC.setMessageBody(body, isHTML: false)
        
        // Attach PDF
        do {
            let pdfData = try Data(contentsOf: pdfURL)
            mailVC.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: pdfURL.lastPathComponent)
        } catch {
            print("Error loading PDF attachment: \(error.localizedDescription)")
        }
        
        return mailVC
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView
        
        init(_ parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            parent.dismiss()
        }
    }
}

// MARK: - Email Service Helper

class EmailService {
    static let shared = EmailService()
    private init() {}
    
    /// Verifica se il dispositivo può inviare email
    func canSendEmail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }
}
