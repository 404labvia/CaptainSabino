//
//  CameraReceiptView.swift
//  CaptainSabino
//
//  View per fotografare gli scontrini
//

import SwiftUI
import AVFoundation
import Combine

struct CameraReceiptView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()
    let onCapture: (UIImage) -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            #if targetEnvironment(simulator)
            // SIMULATOR: Mostra immagine demo invece della fotocamera
            simulatorCameraView
            #else
            // DEVICE: Fotocamera reale
            realCameraView
            #endif
        }
        .background(Color.black)
        .onAppear {
            #if !targetEnvironment(simulator)
            camera.checkPermissionsAndStart()
            #endif
        }
        .onDisappear {
            #if !targetEnvironment(simulator)
            camera.stopSession()
            #endif
        }
    }

    // MARK: - Simulator Camera View (Demo)

    #if targetEnvironment(simulator)
    private var simulatorCameraView: some View {
        ZStack {
            // Background nero
            Color.black.ignoresSafeArea()

            // Immagine demo dello scontrino
            if let demoImage = UIImage(named: "DemoReceipt") {
                Image(uiImage: demoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 100)
            } else {
                // Fallback se immagine non trovata
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                    Text("Add 'DemoReceipt' to Assets")
                        .foregroundColor(.gray)
                }
            }

            // Controls (identici al reale)
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.5))
                            )
                    }
                    .padding()

                    Spacer()
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 12) {
                    // Shutter button - usa immagine demo
                    Button {
                        if let demoImage = UIImage(named: "DemoReceipt") {
                            onCapture(demoImage)
                            dismiss()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 70, height: 70)

                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 85, height: 85)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
    #endif

    // MARK: - Real Camera View (Device)

    private var realCameraView: some View {
        Group {
            if camera.isAuthorized {
                ZStack {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()

                    // Controls
                    VStack {
                        // Top bar
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        Circle()
                                            .fill(.black.opacity(0.5))
                                    )
                            }
                            .padding()

                            Spacer()
                        }

                        Spacer()

                        // Bottom controls
                        VStack(spacing: 12) {
                            // Shutter button
                            Button {
                                camera.capturePhoto { image in
                                    if let image = image {
                                        onCapture(image)
                                        dismiss()
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 70, height: 70)

                                    Circle()
                                        .stroke(.white, lineWidth: 3)
                                        .frame(width: 85, height: 85)
                                }
                            }
                            .padding(.bottom, 30)
                        }
                    }
                }

            } else if camera.permissionDenied {
                // Permission denied view
                PermissionDeniedView(onDismiss: {
                    dismiss()
                })

            } else {
                // Loading
                ProgressView("Starting camera...")
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Store layer in context for frame updates
        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Permission Denied View

struct PermissionDeniedView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("CaptainSabino needs camera access to scan receipts. Please enable it in Settings.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Camera Manager

@MainActor
class CameraManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isAuthorized = false
    @Published var permissionDenied = false

    // MARK: - Properties

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?

    // MARK: - Permission & Setup

    func checkPermissionsAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCameraSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { [weak self] in
                    if granted {
                        self?.isAuthorized = true
                        self?.setupCameraSession()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }

        case .denied, .restricted:
            permissionDenied = true

        @unknown default:
            permissionDenied = true
        }
    }

    private func setupCameraSession() {
        session.beginConfiguration()

        // Input: back camera
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            print("❌ Camera non disponibile")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("❌ Errore camera input: \(error)")
            session.commitConfiguration()
            return
        }

        // Output: photo
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // Preset: high quality
        session.sessionPreset = .photo

        session.commitConfiguration()

        // Start session
        Task {
            session.startRunning()
        }
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    // MARK: - Capture Photo

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.captureCompletion = completion

        let settings = AVCapturePhotoSettings()

        // Flash auto (se necessario)
        if photoOutput.supportedFlashModes.contains(.auto) {
            settings.flashMode = .auto
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("❌ Errore capture: \(error)")
            Task { @MainActor in
                self.captureCompletion?(nil)
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                self.captureCompletion?(nil)
            }
            return
        }

        // Ritorna immagine al main thread
        Task { @MainActor in
            self.captureCompletion?(image)
        }
    }
}

// MARK: - Preview

#Preview {
    CameraReceiptView { image in
        print("Captured image: \(image.size)")
    }
}
