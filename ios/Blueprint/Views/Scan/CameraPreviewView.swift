import AVFoundation
import SwiftUI

/// Live camera preview backed by AVCaptureVideoPreviewLayer.
/// Pinned to portrait so the feed is always upright — you can prop the phone
/// up and step back without the image rotating.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            pinPortrait()
        }

        /// Always render the feed as portrait, regardless of how the phone is held.
        private func pinPortrait() {
            guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
            connection.videoOrientation = .portrait
        }
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.connection?.videoOrientation = .portrait
    }
}
