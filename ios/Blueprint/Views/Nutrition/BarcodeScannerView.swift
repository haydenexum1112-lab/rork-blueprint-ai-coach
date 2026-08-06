import AVFoundation
import SwiftUI

/// Full-screen barcode scanner that detects EAN-13, UPC-A, EAN-8, and Code-128 barcodes.
/// Calls `onDetected` with the barcode string when a match is found. Includes a reticle,
/// torch toggle, and haptic feedback on detection.
struct BarcodeScannerView: View {
    let onDetected: (String) -> Void
    let onClose: () -> Void

    @State private var session = AVCaptureSession()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var isTorchOn: Bool = false
    @State private var isScanning: Bool = true
    @State private var hasCamera: Bool = true
    @State private var setupError: String?
    @State private var barcodeDelegate: BarcodeDelegate?

    private let captureQueue = DispatchQueue(label: "barcode-scanner", qos: .userInitiated)
    private let metadataObjects: [AVMetadataObject.ObjectType] = [
        .ean13, .ean8, .upce, .pdf417, .qr, .code128, .code39, .code93,
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if hasCamera {
                BarcodePreviewLayerView(session: session)
                    .ignoresSafeArea()
            } else {
                noCameraView
            }

            // Overlay UI
            VStack {
                topBar
                Spacer()
                if hasCamera {
                    reticleOverlay
                    Spacer()
                    bottomHint
                }
            }
        }
        .task { setupCamera() }
        .onDisappear { stopSession() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                Haptics.impact(.light)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            Spacer()
            Text("Scan barcode")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                toggleTorch()
            } label: {
                Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isTorchOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .disabled(!hasCamera)
            .opacity(hasCamera ? 1 : 0.4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Reticle

    private var reticleOverlay: some View {
        ZStack {
            // Dimming around the reticle
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: 280, height: 160)
                                .blendMode(.destinationOut)
                        }
                }
                .allowsHitTesting(false)

            // Reticle border
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
                .frame(width: 280, height: 160)
                .overlay(alignment: .center) {
                    // Scanning line animation
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Theme.accent.opacity(0.8), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .frame(maxWidth: 260)
                        .offset(y: scanningLineOffset)
                        .onAppear { startScanningLineAnimation() }
                }
        }
    }

    @State private var scanningLineOffset: CGFloat = -70
    @State private var animationDir: Bool = true

    private func startScanningLineAnimation() {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: true)) {
            scanningLineOffset = 70
        }
    }

    // MARK: - Bottom hint

    private var bottomHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.6))
            Text("Point at a product barcode")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text("Works with EAN, UPC, and QR codes")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.bottom, 50)
    }

    // MARK: - No camera

    private var noCameraView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.5))
            Text("No camera available")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text(setupError ?? "Camera could not be started. Try logging the food manually.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                onClose()
            } label: {
                Text("Close")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.accent))
            }
        }
    }

    // MARK: - Camera setup

    private func setupCamera() {
        // Create and retain the delegate on the main thread so it isn't
        // deallocated when the setup closure returns (AVFoundation stores
        // delegates as weak references).
        let delegate = BarcodeDelegate(onDetected: { barcode in
            DispatchQueue.main.async { handleDetection(barcode) }
        })
        barcodeDelegate = delegate

        captureQueue.async {
            session.beginConfiguration()
            session.sessionPreset = .high

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external],
                mediaType: .video,
                position: .back
            )
            guard let device = discovery.devices.first else {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    hasCamera = false
                    setupError = "No camera device found."
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }

                let metadataOutput = AVCaptureMetadataOutput()
                if session.canAddOutput(metadataOutput) {
                    session.addOutput(metadataOutput)
                    let available = Set(metadataOutput.availableMetadataObjectTypes)
                    let supported = metadataObjects.filter { available.contains($0) }
                    if !supported.isEmpty {
                        metadataOutput.metadataObjectTypes = supported
                    }
                    metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
                }

                session.commitConfiguration()
                session.startRunning()
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    hasCamera = false
                    setupError = error.localizedDescription
                }
            }
        }
    }

    private func stopSession() {
        captureQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
            barcodeDelegate = nil
            if let device = AVCaptureDevice.default(for: .video), device.hasTorch, device.torchMode == .on {
                try? device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
            }
        }
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isTorchOn.toggle()
            device.torchMode = isTorchOn ? .on : .off
            device.unlockForConfiguration()
            Haptics.impact(.light)
        } catch {
            // Torch toggle failed — ignore
        }
    }

    private func handleDetection(_ barcode: String) {
        guard isScanning else { return }
        isScanning = false
        Haptics.success()
        // Brief visual confirmation — then notify
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDetected(barcode)
        }
    }
}

// MARK: - Metadata delegate

private final class BarcodeDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let onDetected: (String) -> Void

    init(onDetected: @escaping (String) -> Void) {
        self.onDetected = onDetected
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for obj in metadataObjects {
            guard let readable = obj as? AVMetadataMachineReadableCodeObject,
                  let value = readable.stringValue else { continue }
            onDetected(value)
        }
    }
}

// MARK: - Preview layer

private struct BarcodePreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if let connection = uiView.previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}
