import Foundation
import Vision
import UIKit

/// Validates that a captured frame actually shows a full human physique,
/// not a close-up, selfie, or non-body photo. Uses Vision body pose + face detection.
nonisolated enum PhotoValidator {

    /// Result of validating one frame.
    struct Result {
        let isValid: Bool
        let reason: RejectionReason?
        let bodyBox: CGRect?
        let faceBox: CGRect?
    }

    enum RejectionReason: String {
        case noBody = "No full body detected — step back so your whole torso and legs are visible."
        case tooFar = "You're too far away — move closer so your body fills more of the frame."
        case selfie = "This looks like a close-up selfie — step back so your full body is in frame."
        case lowConfidence = "We couldn't clearly detect a body — try again with better lighting and a plain background."
        case notBody = "This doesn't appear to be a physique photo — retake with your full body visible."

        /// Whether this rejection should hard-block analysis or just show a warning.
        var isHardBlock: Bool {
            self == .selfie
        }
    }

    /// Validate a single frame's image data.
    static func validate(_ data: Data) async -> Result {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            return Result(isValid: false, reason: .notBody, bodyBox: nil, faceBox: nil)
        }

        let bodyBox = await detectBodyBox(cgImage)
        let faceBox = await detectFaceBox(cgImage)

        // No body detected at all.
        guard let bodyBox else {
            // Face but no body → selfie or headshot — hard block.
            if faceBox != nil {
                return Result(isValid: false, reason: .selfie, bodyBox: nil, faceBox: faceBox)
            }
            // No body AND no face — Vision may have just failed to detect.
            // Don't hard-block; let the user proceed with a soft warning.
            return Result(isValid: true, reason: nil, bodyBox: nil, faceBox: nil)
        }

        // Normalized coords (0–1).
        let bodyHeight = bodyBox.height

        // Reject if body is extremely tiny — less than 15% of frame height.
        if bodyHeight < 0.15 {
            return Result(isValid: false, reason: .tooFar, bodyBox: bodyBox, faceBox: faceBox)
        }

        // Reject if face box is huge relative to body (selfie/close-up headshot) — hard block.
        if let faceBox {
            let faceHeightVsBody = faceBox.height / max(bodyBox.height, 0.001)
            // Face > 85% of body height → definitely a headshot.
            if faceHeightVsBody > 0.85 {
                return Result(isValid: false, reason: .selfie, bodyBox: bodyBox, faceBox: faceBox)
            }
        }

        return Result(isValid: true, reason: nil, bodyBox: bodyBox, faceBox: faceBox)
    }

    /// Validate all three frames; returns first failure or success.
    static func validateAll(_ frames: [Data]) async -> (valid: Bool, failures: [Int: RejectionReason]) {
        var failures: [Int: RejectionReason] = [:]
        for (index, frame) in frames.enumerated() {
            let result = await validate(frame)
            if !result.isValid, let reason = result.reason {
                failures[index] = reason
            }
        }
        return (failures.isEmpty, failures)
    }

    // MARK: - Vision

    private static func detectBodyBox(_ cgImage: CGImage) async -> CGRect? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CGRect?, Never>) in
            let request = VNDetectHumanRectanglesRequest { request, _ in
                let observations = request.results as? [VNHumanObservation]
                let largest = observations?.max(by: { $0.boundingBox.height < $1.boundingBox.height })
                continuation.resume(returning: largest?.boundingBox)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private static func detectFaceBox(_ cgImage: CGImage) async -> CGRect? {
        await withCheckedContinuation { (continuation: CheckedContinuation<CGRect?, Never>) in
            let request = VNDetectFaceRectanglesRequest { request, _ in
                let observations = request.results as? [VNFaceObservation]
                let largest = observations?.max(by: { $0.boundingBox.height < $1.boundingBox.height })
                continuation.resume(returning: largest?.boundingBox)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
