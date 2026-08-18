import AVFoundation
import Foundation
import UIKit

/// AVFoundation capture pipeline. Includes `.external` so the cloud simulator's
/// injected webcam is discovered like a real device camera.
@Observable
final class CameraService: NSObject {
    enum Status {
        case idle
        case denied
        case noCamera
        case running
    }

    var status: Status = .idle
    let session = AVCaptureSession()

    @ObservationIgnored private var photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored private var currentPosition: AVCaptureDevice.Position = .back
    @ObservationIgnored private var photoContinuation: CheckedContinuation<Data?, Never>?

    func start() async {
        let authorized = await requestPermission()
        guard authorized else {
            status = .denied
            return
        }
        guard configureSession() else {
            status = .noCamera
            return
        }
        startSessionRunning()
        status = .running
    }

    func stop() {
        let session = self.session
        nonisolated(unsafe) let unsafeSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            if unsafeSession.isRunning {
                unsafeSession.stopRunning()
            }
        }
    }

    func flipCamera() {
        currentPosition = currentPosition == .back ? .front : .back
        _ = configureSession()
    }

    func capturePhoto() async -> Data? {
        guard status == .running else { return nil }
        return await withCheckedContinuation { continuation in
            photoContinuation = continuation
            var settings = AVCapturePhotoSettings()
            // Pin captured photo orientation to portrait so saved frames match the preview.
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            if let connection = photoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Private

    private func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func discoverCamera() -> AVCaptureDevice? {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInDualWideCamera]
        if #available(iOS 17.0, *) {
            deviceTypes.append(.external)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        let devices = discovery.devices
        if let match = devices.first(where: { $0.position == currentPosition }) {
            return match
        }
        return devices.first
    }

    private func configureSession() -> Bool {
        guard let device = discoverCamera(), let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        for existing in session.inputs {
            session.removeInput(existing)
        }
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        if !session.outputs.contains(photoOutput) {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            } else {
                session.commitConfiguration()
                return false
            }
        }
        session.commitConfiguration()
        return true
    }

    private func startSessionRunning() {
        nonisolated(unsafe) let unsafeSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            if !unsafeSession.isRunning {
                unsafeSession.startRunning()
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            self.photoContinuation?.resume(returning: data)
            self.photoContinuation = nil
        }
    }
}
