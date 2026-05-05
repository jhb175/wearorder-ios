import Foundation

struct WardrobeInlineImageMigrationResult: Equatable {
    let scannedItemCount: Int
    let migratedItemCount: Int
    let failedItemCount: Int

    var hasMigratedAnything: Bool {
        migratedItemCount > 0
    }

    var isFullySuccessful: Bool {
        failedItemCount == 0
    }
}

/// Idempotently moves any leftover inline `imageData` / `thumbnailData` blobs
/// on `WardrobeItem` records into the file-backed store, then clears the
/// inline fields. This bridges V1 records (created before the file store
/// existed) onto the file-backed representation so a future V2 schema can
/// drop the inline columns safely.
@MainActor
enum WardrobeInlineImageMigrator {
    /// Default per-item migration step: writes blobs to the shared file
    /// store and clears the inline columns.
    static let defaultMigrateItem: @MainActor (WardrobeItem) throws -> Void = { item in
        try item.persistInlineImageDataToFiles(clearInlineData: true)
    }

    @discardableResult
    static func migrate(
        items: [WardrobeItem],
        migrateItem: @MainActor (WardrobeItem) throws -> Void = defaultMigrateItem
    ) -> WardrobeInlineImageMigrationResult {
        var migrated = 0
        var failed = 0
        var scanned = 0

        for item in items {
            guard item.imageData != nil, item.imageFileName == nil else { continue }
            scanned += 1
            do {
                try migrateItem(item)
                migrated += 1
            } catch {
                failed += 1
            }
        }

        return WardrobeInlineImageMigrationResult(
            scannedItemCount: scanned,
            migratedItemCount: migrated,
            failedItemCount: failed
        )
    }
}
