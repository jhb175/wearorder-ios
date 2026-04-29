import SwiftUI
import ImageIO

#if canImport(UIKit)
import UIKit
private typealias WardrobeCachedPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias WardrobeCachedPlatformImage = NSImage
#endif

struct WardrobeItemImageView: View {
    enum ImageRole: String {
        case thumbnail
        case detail
    }

    let item: WardrobeItem
    var role: ImageRole = .thumbnail
    var cornerRadius: CGFloat = 18
    var symbolFont: Font = .title3.weight(.semibold)
    var contentMode: ContentMode = .fill
    @State private var decodedImage: WardrobeCachedPlatformImage?
    @State private var decodedCacheKey: String?

    var body: some View {
        let currentImageSource = imageSource
        let currentCacheKey = currentImageSource?.cacheKey ?? cacheKey
        let cachedImage = WardrobeImageCache.shared.cachedImage(for: currentCacheKey)

        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(item.tintColor.gradient)
            .overlay {
                if let image = cachedImage ?? (decodedCacheKey == currentCacheKey ? decodedImage : nil) {
                    platformImageView(image)
                } else {
                    Image(systemName: item.imageSymbol)
                        .font(symbolFont)
                        .foregroundStyle(.white.opacity(0.94))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: currentCacheKey) {
                await loadImageIfNeeded(source: currentImageSource, cacheKey: currentCacheKey)
            }
    }

    private var imageSource: WardrobeImageSource? {
        switch role {
        case .thumbnail:
            if let fileURL = WardrobeImageFileStore.shared.url(for: item.thumbnailFileName ?? item.imageFileName) {
                return WardrobeImageSource(fileURL: fileURL, inlineData: nil, cacheKey: cacheKey)
            }
            return (item.thumbnailData ?? item.imageData).map { WardrobeImageSource(fileURL: nil, inlineData: $0, cacheKey: cacheKey) }
        case .detail:
            if let fileURL = WardrobeImageFileStore.shared.url(for: item.imageFileName ?? item.thumbnailFileName) {
                return WardrobeImageSource(fileURL: fileURL, inlineData: nil, cacheKey: cacheKey)
            }
            return (item.imageData ?? item.thumbnailData).map { WardrobeImageSource(fileURL: nil, inlineData: $0, cacheKey: cacheKey) }
        }
    }

    private var cacheKey: String {
        [
            item.id.uuidString,
            role.rawValue,
            String(Int(item.lastModifiedAt.timeIntervalSince1970)),
            item.thumbnailFileName ?? "no-thumb-file",
            item.imageFileName ?? "no-image-file",
            String((item.thumbnailData ?? item.imageData)?.count ?? 0)
        ].joined(separator: "-")
    }

    private var decodeMaxPixelSize: CGFloat {
        switch role {
        case .thumbnail:
            420
        case .detail:
            1600
        }
    }

    @ViewBuilder
    private func platformImageView(_ image: WardrobeCachedPlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: contentMode)
        #endif
    }

    private func loadImageIfNeeded(source: WardrobeImageSource?, cacheKey: String) async {
        guard let source else {
            decodedImage = nil
            decodedCacheKey = nil
            return
        }

        if let cachedImage = WardrobeImageCache.shared.cachedImage(for: cacheKey) {
            decodedImage = cachedImage
            decodedCacheKey = cacheKey
            return
        }

        decodedImage = nil
        decodedCacheKey = nil
        let maxPixelSize = decodeMaxPixelSize
        let decodedResult = await Task.detached(priority: .utility) { () -> (CGImage, Int)? in
            let data: Data?
            if let inlineData = source.inlineData {
                data = inlineData
            } else if let fileURL = source.fileURL {
                data = try? Data(contentsOf: fileURL)
            } else {
                data = nil
            }
            guard let data else { return nil }
            guard let cgImage = WardrobeImageDecoder.decodeCGImage(from: data, maxPixelSize: maxPixelSize) else {
                return nil
            }
            return (cgImage, data.count)
        }.value

        guard !Task.isCancelled else { return }
        guard let (decodedCGImage, sourceByteCount) = decodedResult else { return }
        let decoded = WardrobeImageCache.platformImage(from: decodedCGImage)
        WardrobeImageCache.shared.store(decoded, for: cacheKey, sourceByteCount: sourceByteCount)
        decodedImage = decoded
        decodedCacheKey = cacheKey
    }
}

private struct WardrobeImageSource: Sendable {
    let fileURL: URL?
    let inlineData: Data?
    let cacheKey: String
}

private final class WardrobeImageCache {
    static let shared = WardrobeImageCache()

    #if canImport(UIKit) || canImport(AppKit)
    private let cache = NSCache<NSString, WardrobeCachedPlatformImage>()
    #endif

    private init() {
        #if canImport(UIKit) || canImport(AppKit)
        cache.countLimit = 240
        cache.totalCostLimit = 36 * 1024 * 1024
        #endif
    }

    func cachedImage(for cacheKey: String) -> WardrobeCachedPlatformImage? {
        #if canImport(UIKit) || canImport(AppKit)
        cache.object(forKey: NSString(string: cacheKey))
        #else
        nil
        #endif
    }

    func store(
        _ image: WardrobeCachedPlatformImage,
        for cacheKey: String,
        sourceByteCount: Int
    ) {
        #if canImport(UIKit) || canImport(AppKit)
        cache.setObject(image, forKey: NSString(string: cacheKey), cost: cacheCost(for: image, fallback: sourceByteCount))
        #endif
    }

    static func platformImage(from cgImage: CGImage) -> WardrobeCachedPlatformImage {
        #if canImport(UIKit)
        UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        NSImage(cgImage: cgImage, size: .zero)
        #endif
    }

    private func cacheCost(for image: WardrobeCachedPlatformImage, fallback: Int) -> Int {
        #if canImport(UIKit)
        if let cgImage = image.cgImage {
            return max(fallback, cgImage.bytesPerRow * cgImage.height)
        }
        return fallback
        #elseif canImport(AppKit)
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return max(fallback, cgImage.bytesPerRow * cgImage.height)
        }
        return fallback
        #else
        return fallback
        #endif
    }
}

private enum WardrobeImageDecoder {
    nonisolated static func decodeCGImage(from data: Data, maxPixelSize: CGFloat) -> CGImage? {
        #if canImport(UIKit) || canImport(AppKit)
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize))
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }

        return cgImage
        #else
        return nil
        #endif
    }
}
