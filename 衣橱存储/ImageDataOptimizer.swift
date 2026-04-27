import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ImageDataOptimizer {
    static let defaultMaxDimension: CGFloat = 1400
    static let defaultMaxByteCount = 700_000

    static func optimizedJPEGData(
        from data: Data,
        maxDimension: CGFloat = defaultMaxDimension,
        maxByteCount: Int = defaultMaxByteCount
    ) -> Data? {
        let resizedImageData = resizedJPEGData(from: data, maxDimension: maxDimension, quality: 0.82)
        let candidates = compressionCandidates(from: data, maxDimension: maxDimension)
        let fittingCandidate = candidates
            .filter { $0.count <= maxByteCount }
            .min { $0.count < $1.count }

        if let fittingCandidate {
            return fittingCandidate.count < data.count ? fittingCandidate : data
        }

        guard let smallestCandidate = candidates.min(by: { $0.count < $1.count }) ?? resizedImageData else {
            return nil
        }
        return smallestCandidate.count < data.count ? smallestCandidate : data
    }

    static func scaledSize(for size: CGSize, maxDimension: CGFloat) -> CGSize {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension, largestSide > 0 else { return size }
        let scale = maxDimension / largestSide
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private static func compressionCandidates(from data: Data, maxDimension: CGFloat) -> [Data] {
        [0.82, 0.72, 0.62, 0.52].compactMap { quality in
            resizedJPEGData(from: data, maxDimension: maxDimension, quality: quality)
        }
    }

    private static func resizedJPEGData(from data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let targetSize = scaledSize(for: image.size, maxDimension: maxDimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return renderedImage.jpegData(compressionQuality: quality)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        let targetSize = scaledSize(for: image.size, maxDimension: maxDimension)
        let renderedImage = NSImage(size: targetSize)
        renderedImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )
        renderedImage.unlockFocus()
        guard
            let tiffData = renderedImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #else
        return nil
        #endif
    }
}
