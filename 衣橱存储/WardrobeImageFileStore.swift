import Foundation

struct WardrobeStoredImageFiles: Sendable {
    let imageFileName: String
    let thumbnailFileName: String
}

enum WardrobeImageStoragePreparer {
    nonisolated static func storeImageFilesIfNeeded(
        itemID: UUID,
        imageData: Data?,
        thumbnailData: Data?
    ) throws -> WardrobeStoredImageFiles? {
        guard let imageData else { return nil }
        let resolvedThumbnailData = thumbnailData
            ?? ImageDataOptimizer.thumbnailJPEGData(from: imageData)
            ?? imageData
        return try WardrobeImageFileStore.shared.storeImageSet(
            itemID: itemID,
            imageData: imageData,
            thumbnailData: resolvedThumbnailData
        )
    }
}

final class WardrobeImageFileStore: @unchecked Sendable {
    nonisolated static let shared = WardrobeImageFileStore()

    private let rootDirectoryURL: URL

    private init() {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        rootDirectoryURL = applicationSupportURL
            .appendingPathComponent("WearOrderImages", isDirectory: true)
    }

    nonisolated func url(for fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return rootDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    nonisolated func data(for fileName: String?) -> Data? {
        guard let fileURL = url(for: fileName) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    nonisolated func byteCount(for fileName: String?) -> Int? {
        guard let fileURL = url(for: fileName),
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.intValue
    }

    nonisolated func storeImageSet(
        itemID: UUID,
        imageData: Data,
        thumbnailData: Data,
        replacing oldFiles: WardrobeStoredImageFiles? = nil
    ) throws -> WardrobeStoredImageFiles {
        try ensureDirectoryExists()

        let imageFileName = "\(itemID.uuidString)-display.jpg"
        let thumbnailFileName = "\(itemID.uuidString)-thumb.jpg"
        let imageURL = rootDirectoryURL.appendingPathComponent(imageFileName, isDirectory: false)
        let thumbnailURL = rootDirectoryURL.appendingPathComponent(thumbnailFileName, isDirectory: false)

        try imageData.write(to: imageURL, options: [.atomic])
        try thumbnailData.write(to: thumbnailURL, options: [.atomic])

        if let oldFiles {
            remove(fileName: oldFiles.imageFileName, unlessEqualTo: imageFileName)
            remove(fileName: oldFiles.thumbnailFileName, unlessEqualTo: thumbnailFileName)
        }

        return WardrobeStoredImageFiles(
            imageFileName: imageFileName,
            thumbnailFileName: thumbnailFileName
        )
    }

    nonisolated func remove(fileName: String?) {
        guard let fileURL = url(for: fileName) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    nonisolated private func remove(fileName: String?, unlessEqualTo retainedFileName: String) {
        guard fileName != retainedFileName else { return }
        remove(fileName: fileName)
    }

    nonisolated private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: rootDirectoryURL,
            withIntermediateDirectories: true
        )
    }
}

extension WardrobeItem {
    func persistInlineImageDataToFiles(clearInlineData: Bool = true) throws {
        guard let imageData else {
            clearImageStorage(removeFiles: true)
            return
        }

        let thumbnailData = thumbnailData ?? ImageDataOptimizer.thumbnailJPEGData(from: imageData) ?? imageData
        let files = try WardrobeImageFileStore.shared.storeImageSet(
            itemID: id,
            imageData: imageData,
            thumbnailData: thumbnailData,
            replacing: storedImageFiles
        )
        applyStoredImageFiles(files, clearInlineData: clearInlineData)
    }

    func clearImageStorage(removeFiles: Bool) {
        if removeFiles {
            WardrobeImageFileStore.shared.remove(fileName: imageFileName)
            WardrobeImageFileStore.shared.remove(fileName: thumbnailFileName)
        }
        imageFileName = nil
        thumbnailFileName = nil
        imageData = nil
        thumbnailData = nil
    }
}
