import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct WardrobeBackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct WardrobeBackupRestoreSummary {
    let insertedItems: Int
    let updatedItems: Int
    let insertedOutfits: Int
    let updatedOutfits: Int
    let insertedPlans: Int
    let updatedPlans: Int
    let plansForNotificationSync: [OutfitPlan]

    var totalRecordsChanged: Int {
        insertedItems + updatedItems + insertedOutfits + updatedOutfits + insertedPlans + updatedPlans
    }

    func feedbackMessage(scheduledNotifications: Int) -> String {
        let recordText = [
            "衣物 \(insertedItems + updatedItems)",
            "OOTD \(insertedOutfits + updatedOutfits)",
            "计划 \(insertedPlans + updatedPlans)"
        ].joined(separator: "、")

        guard !plansForNotificationSync.isEmpty else {
            return "已恢复 \(recordText)。当前备份没有需要同步的提醒。"
        }

        return "已恢复 \(recordText)。提醒已重新同步 \(scheduledNotifications)/\(plansForNotificationSync.count) 条。"
    }
}

enum WardrobeBackupError: LocalizedError {
    case emptyFile
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            "备份文件为空，无法恢复。"
        case .unsupportedVersion(let version):
            "备份版本 \(version) 高于当前 App 支持版本，请先更新 App。"
        }
    }
}

@MainActor
enum WardrobeBackupManager {
    static let currentSchemaVersion = 2

    static func makeBackupFile(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan],
        exportedAt: Date = .now
    ) throws -> (file: WardrobeBackupFile, filename: String) {
        let data = try exportData(
            items: items,
            outfits: outfits,
            plans: plans,
            exportedAt: exportedAt
        )
        return (
            WardrobeBackupFile(data: data),
            defaultFilename(exportedAt: exportedAt)
        )
    }

    static func exportData(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan],
        exportedAt: Date = .now
    ) throws -> Data {
        let payload = WardrobeBackupPayload(
            schemaVersion: currentSchemaVersion,
            exportedAt: exportedAt,
            items: items
                .sorted { $0.createdAt < $1.createdAt }
                .map(WardrobeBackupPayload.ItemRecord.init),
            outfits: outfits
                .sorted { $0.createdAt < $1.createdAt }
                .map(WardrobeBackupPayload.OutfitRecord.init),
            plans: plans
                .sorted { $0.date < $1.date }
                .map(WardrobeBackupPayload.PlanRecord.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }

    @discardableResult
    static func restore(
        from data: Data,
        into context: ModelContext,
        existingItems: [WardrobeItem],
        existingOutfits: [OOTDOutfit],
        existingPlans: [OutfitPlan]
    ) throws -> WardrobeBackupRestoreSummary {
        guard !data.isEmpty else { throw WardrobeBackupError.emptyFile }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(WardrobeBackupPayload.self, from: data)

        guard payload.schemaVersion <= currentSchemaVersion else {
            throw WardrobeBackupError.unsupportedVersion(payload.schemaVersion)
        }

        var itemLookup = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })
        var outfitLookup = Dictionary(uniqueKeysWithValues: existingOutfits.map { ($0.id, $0) })
        var planLookup = Dictionary(uniqueKeysWithValues: existingPlans.map { ($0.id, $0) })

        var insertedItems = 0
        var updatedItems = 0
        var insertedOutfits = 0
        var updatedOutfits = 0
        var insertedPlans = 0
        var updatedPlans = 0

        for record in payload.items {
            if let item = itemLookup[record.id] {
                record.apply(to: item)
                updatedItems += 1
            } else {
                let item = record.makeModel()
                context.insert(item)
                itemLookup[record.id] = item
                insertedItems += 1
            }
        }

        let activeTodayOutfitID = payload.activeTodayOutfitID

        for record in payload.outfits {
            let todayState = activeTodayOutfitID.map { $0 == record.id } ?? record.isToday
            if let outfit = outfitLookup[record.id] {
                record.apply(to: outfit, itemLookup: itemLookup, isToday: todayState)
                updatedOutfits += 1
            } else {
                let outfit = record.makeModel(itemLookup: itemLookup, isToday: todayState)
                context.insert(outfit)
                outfitLookup[record.id] = outfit
                insertedOutfits += 1
            }
        }

        if let activeTodayOutfitID {
            for outfit in outfitLookup.values where outfit.id != activeTodayOutfitID {
                outfit.isToday = false
            }
        }

        var importedPlans: [OutfitPlan] = []
        for record in payload.plans {
            if let plan = planLookup[record.id] {
                record.apply(to: plan, outfitLookup: outfitLookup)
                importedPlans.append(plan)
                updatedPlans += 1
            } else {
                let plan = record.makeModel(outfitLookup: outfitLookup)
                context.insert(plan)
                planLookup[record.id] = plan
                importedPlans.append(plan)
                insertedPlans += 1
            }
        }

        return WardrobeBackupRestoreSummary(
            insertedItems: insertedItems,
            updatedItems: updatedItems,
            insertedOutfits: insertedOutfits,
            updatedOutfits: updatedOutfits,
            insertedPlans: insertedPlans,
            updatedPlans: updatedPlans,
            plansForNotificationSync: importedPlans
        )
    }

    private static func defaultFilename(exportedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "wardrobe-backup-\(formatter.string(from: exportedAt)).json"
    }
}

private struct WardrobeBackupPayload: Codable {
    let appName = AppReleaseInfo.appName
    let schemaVersion: Int
    let exportedAt: Date
    let items: [ItemRecord]
    let outfits: [OutfitRecord]
    let plans: [PlanRecord]

    enum CodingKeys: String, CodingKey {
        case appName
        case schemaVersion
        case exportedAt
        case items
        case outfits
        case plans
    }

    var activeTodayOutfitID: UUID? {
        outfits
            .filter(\.isToday)
            .sorted {
                ($0.updatedAt ?? $0.createdAt) > ($1.updatedAt ?? $1.createdAt)
            }
            .first?
            .id
    }

    struct ItemRecord: Codable {
        let id: UUID
        let name: String
        let category: String
        let colorName: String
        let season: String
        let imageSymbol: String
        let imageData: Data?
        let styleTagsText: String
        let notes: String
        let brand: String?
        let size: String?
        let purchasePrice: Double?
        let purchaseDate: Date?
        let purchaseChannel: String?
        let careNotes: String?
        let isFavorite: Bool
        let createdAt: Date
        let updatedAt: Date?

        init(item: WardrobeItem) {
            id = item.id
            name = item.name
            category = item.category
            colorName = item.colorName
            season = item.season
            imageSymbol = item.imageSymbol
            imageData = item.imageData
            styleTagsText = item.styleTagsText
            notes = item.notes
            brand = item.trimmedBrand
            size = item.trimmedSize
            purchasePrice = item.purchasePrice
            purchaseDate = item.purchaseDate
            purchaseChannel = item.trimmedPurchaseChannel
            careNotes = item.trimmedCareNotes
            isFavorite = item.isFavorite
            createdAt = item.createdAt
            updatedAt = item.updatedAt
        }

        func makeModel() -> WardrobeItem {
            WardrobeItem(
                id: id,
                name: name,
                category: category,
                colorName: colorName,
                season: season,
                imageSymbol: imageSymbol,
                imageData: imageData,
                styleTagsText: styleTagsText,
                notes: notes,
                brand: brand ?? "",
                size: size ?? "",
                purchasePrice: purchasePrice,
                purchaseDate: purchaseDate,
                purchaseChannel: purchaseChannel ?? "",
                careNotes: careNotes ?? "",
                isFavorite: isFavorite,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        func apply(to item: WardrobeItem) {
            item.name = name
            item.category = category
            item.colorName = colorName
            item.season = season
            item.imageSymbol = imageSymbol
            item.imageData = imageData
            item.styleTagsText = styleTagsText
            item.notes = notes
            item.brand = normalizedOptional(brand)
            item.size = normalizedOptional(size)
            item.purchasePrice = purchasePrice
            item.purchaseDate = purchaseDate
            item.purchaseChannel = normalizedOptional(purchaseChannel)
            item.careNotes = normalizedOptional(careNotes)
            item.isFavorite = isFavorite
            item.createdAt = createdAt
            item.updatedAt = updatedAt
        }

        private func normalizedOptional(_ text: String?) -> String? {
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    struct OutfitRecord: Codable {
        let id: UUID
        let title: String
        let notes: String
        let createdAt: Date
        let updatedAt: Date?
        let isToday: Bool
        let topItemID: UUID?
        let bottomItemID: UUID?
        let outerwearItemID: UUID?
        let shoesItemID: UUID?
        let bagItemID: UUID?
        let accessoryItemID: UUID?

        init(outfit: OOTDOutfit) {
            id = outfit.id
            title = outfit.title
            notes = outfit.notes
            createdAt = outfit.createdAt
            updatedAt = outfit.updatedAt
            isToday = outfit.isToday
            topItemID = outfit.topItem?.id
            bottomItemID = outfit.bottomItem?.id
            outerwearItemID = outfit.outerwearItem?.id
            shoesItemID = outfit.shoesItem?.id
            bagItemID = outfit.bagItem?.id
            accessoryItemID = outfit.accessoryItem?.id
        }

        func makeModel(
            itemLookup: [UUID: WardrobeItem],
            isToday: Bool
        ) -> OOTDOutfit {
            OOTDOutfit(
                id: id,
                title: title,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isToday: isToday,
                topItem: topItemID.flatMap { itemLookup[$0] },
                bottomItem: bottomItemID.flatMap { itemLookup[$0] },
                outerwearItem: outerwearItemID.flatMap { itemLookup[$0] },
                shoesItem: shoesItemID.flatMap { itemLookup[$0] },
                bagItem: bagItemID.flatMap { itemLookup[$0] },
                accessoryItem: accessoryItemID.flatMap { itemLookup[$0] }
            )
        }

        func apply(
            to outfit: OOTDOutfit,
            itemLookup: [UUID: WardrobeItem],
            isToday: Bool
        ) {
            outfit.title = title
            outfit.notes = notes
            outfit.createdAt = createdAt
            outfit.updatedAt = updatedAt
            outfit.isToday = isToday
            outfit.topItem = topItemID.flatMap { itemLookup[$0] }
            outfit.bottomItem = bottomItemID.flatMap { itemLookup[$0] }
            outfit.outerwearItem = outerwearItemID.flatMap { itemLookup[$0] }
            outfit.shoesItem = shoesItemID.flatMap { itemLookup[$0] }
            outfit.bagItem = bagItemID.flatMap { itemLookup[$0] }
            outfit.accessoryItem = accessoryItemID.flatMap { itemLookup[$0] }
        }
    }

    struct PlanRecord: Codable {
        let id: UUID
        let date: Date
        let title: String
        let occasion: String
        let notes: String
        let outfitSummary: String
        let reminderEnabled: Bool
        let reminderDate: Date?
        let createdAt: Date
        let updatedAt: Date?
        let linkedOutfitID: UUID?

        init(plan: OutfitPlan) {
            id = plan.id
            date = plan.date
            title = plan.title
            occasion = plan.occasion
            notes = plan.notes
            outfitSummary = plan.outfitSummary
            reminderEnabled = plan.reminderEnabled
            reminderDate = plan.reminderDate
            createdAt = plan.createdAt
            updatedAt = plan.updatedAt
            linkedOutfitID = plan.linkedOutfit?.id
        }

        func makeModel(outfitLookup: [UUID: OOTDOutfit]) -> OutfitPlan {
            OutfitPlan(
                id: id,
                date: date,
                title: title,
                occasion: occasion,
                notes: notes,
                outfitSummary: outfitSummary,
                reminderEnabled: reminderEnabled,
                reminderDate: reminderDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                linkedOutfit: linkedOutfitID.flatMap { outfitLookup[$0] }
            )
        }

        func apply(
            to plan: OutfitPlan,
            outfitLookup: [UUID: OOTDOutfit]
        ) {
            plan.date = date
            plan.title = title
            plan.occasion = occasion
            plan.notes = notes
            plan.outfitSummary = outfitSummary
            plan.reminderEnabled = reminderEnabled
            plan.reminderDate = reminderDate
            plan.createdAt = createdAt
            plan.updatedAt = updatedAt
            plan.linkedOutfit = linkedOutfitID.flatMap { outfitLookup[$0] }
        }
    }
}
