import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Re-encodes JPEG data against a byte budget using an iterative pixel/quality ladder.
/// Required because the AI gateway rejects request bodies above ~4.5 MB.
nonisolated enum ImageResizer {
    private static let ladder: [(maxPixel: CGFloat, quality: CGFloat)] = [
        (1280, 0.82),
        (1024, 0.78),
        (832, 0.74),
        (640, 0.70),
        (512, 0.65),
    ]

    /// Returns JPEG data at or under `maxBytes`, or nil if impossible.
    static func resize(_ data: Data, maxBytes: Int) -> Data? {
        if data.count <= maxBytes {
            return data
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        for step in ladder {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: step.maxPixel,
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                continue
            }
            guard let encoded = encodeJPEG(thumbnail, quality: step.quality) else {
                continue
            }
            if encoded.count <= maxBytes {
                return encoded
            }
        }
        return nil
    }

    static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return output as Data
    }
}
