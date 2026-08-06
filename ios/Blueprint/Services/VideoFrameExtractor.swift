import AVFoundation
import Foundation

nonisolated enum VideoFrameExtractorError: LocalizedError {
    case unreadable
    case tooShort

    var errorDescription: String? {
        switch self {
        case .unreadable: return "We couldn't read that video. Try a different one."
        case .tooShort: return "That video is too short — record about 20–30 seconds turning slowly."
        }
    }
}

/// Extracts three JPEG frames (≈ front / side / back) from a slow-turn scan video.
nonisolated enum VideoFrameExtractor {
    static func extractFrames(from url: URL) async throws -> [Data] {
        let asset = AVURLAsset(url: url)
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            throw VideoFrameExtractorError.unreadable
        }
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds >= 2 else {
            throw VideoFrameExtractorError.tooShort
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        let fractions: [Double] = [0.08, 0.45, 0.82]
        var frames: [Data] = []
        for fraction in fractions {
            let time = CMTime(seconds: seconds * fraction, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                if let jpeg = ImageResizer.encodeJPEG(cgImage, quality: 0.85) {
                    frames.append(jpeg)
                }
            } catch {
                print("[VideoFrameExtractor] Frame at \(fraction) failed: \(error.localizedDescription)")
            }
        }
        guard frames.count == 3 else {
            throw VideoFrameExtractorError.unreadable
        }
        return frames
    }
}
