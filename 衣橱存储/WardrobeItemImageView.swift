import SwiftUI

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

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(item.tintColor.gradient)
            .overlay {
                if let image = WardrobeImageCache.shared.image(for: imageData, cacheKey: cacheKey) {
                    #if canImport(UIKit)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                    #elseif canImport(AppKit)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                    #endif
                } else {
                    Image(systemName: item.imageSymbol)
                        .font(symbolFont)
                        .foregroundStyle(.white.opacity(0.94))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var imageData: Data? {
        switch role {
        case .thumbnail:
            item.preferredThumbnailData
        case .detail:
            item.imageData ?? item.thumbnailData
        }
    }

    private var cacheKey: String {
        [
            item.id.uuidString,
            role.rawValue,
            String(Int(item.lastModifiedAt.timeIntervalSince1970)),
            String(imageData?.count ?? 0)
        ].joined(separator: "-")
    }
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

    func image(for data: Data?, cacheKey: String) -> WardrobeCachedPlatformImage? {
        #if canImport(UIKit) || canImport(AppKit)
        guard let data else { return nil }
        let key = NSString(string: cacheKey)

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        guard let image = WardrobeCachedPlatformImage(data: data) else {
            return nil
        }

        cache.setObject(image, forKey: key, cost: data.count)
        return image
        #else
        return nil
        #endif
    }
}
