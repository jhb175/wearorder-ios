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
    let imageFileNamesForCleanup: [String]
    let imageFileNamesForRollback: [String]

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

private struct ItemImageRestoreChange {
    let oldFileNamesForCleanup: [String]
    let newFileNamesForRollback: [String]
}

private extension Optional where Wrapped == WardrobeStoredImageFiles {
    var fileNames: [String] {
        guard let self else { return [] }
        return [self.imageFileName, self.thumbnailFileName]
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
    static let currentSchemaVersion = 3

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
        var imageFileNamesForCleanup: [String] = []
        var imageFileNamesForRollback: [String] = []

        do {
            for record in payload.items {
                if let item = itemLookup[record.id] {
                    let imageChange = try record.apply(to: item)
                    imageFileNamesForCleanup.append(contentsOf: imageChange.oldFileNamesForCleanup)
                    imageFileNamesForRollback.append(contentsOf: imageChange.newFileNamesForRollback)
                    updatedItems += 1
                } else {
                    let restoredItem = try record.makeModel()
                    imageFileNamesForRollback.append(contentsOf: restoredItem.newFileNamesForRollback)
                    context.insert(restoredItem.item)
                    itemLookup[record.id] = restoredItem.item
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
                plansForNotificationSync: importedPlans,
                imageFileNamesForCleanup: Array(Set(imageFileNamesForCleanup)),
                imageFileNamesForRollback: Array(Set(imageFileNamesForRollback))
            )
        } catch {
            for fileName in imageFileNamesForRollback {
                WardrobeImageFileStore.shared.remove(fileName: fileName)
            }
            throw error
        }
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
        let importBatchID: UUID?
        let createdAt: Date
        let updatedAt: Date?

        init(item: WardrobeItem) {
            id = item.id
            name = item.name
            category = item.category
            colorName = item.colorName
            season = item.season
            imageSymbol = item.imageSymbol
            imageData = item.displayImageData
            styleTagsText = item.styleTagsText
            notes = item.notes
            brand = item.trimmedBrand
            size = item.trimmedSize
            purchasePrice = item.purchasePrice
            purchaseDate = item.purchaseDate
            purchaseChannel = item.trimmedPurchaseChannel
            careNotes = item.trimmedCareNotes
            isFavorite = item.isFavorite
            importBatchID = item.importBatchID
            createdAt = item.createdAt
            updatedAt = item.updatedAt
        }

        func makeModel() throws -> (item: WardrobeItem, newFileNamesForRollback: [String]) {
            let restoredFiles = try restoredImageFiles()
            let item = WardrobeItem(
                id: id,
                name: name,
                category: category,
                colorName: colorName,
                season: season,
                imageSymbol: imageSymbol,
                imageData: nil,
                thumbnailData: nil,
                imageFileName: restoredFiles?.imageFileName,
                thumbnailFileName: restoredFiles?.thumbnailFileName,
                styleTagsText: styleTagsText,
                notes: notes,
                brand: brand ?? "",
                size: size ?? "",
                purchasePrice: purchasePrice,
                purchaseDate: purchaseDate,
                purchaseChannel: purchaseChannel ?? "",
                careNotes: careNotes ?? "",
                isFavorite: isFavorite,
                importBatchID: importBatchID,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
            return (item, restoredFiles.fileNames)
        }

        func apply(to item: WardrobeItem) throws -> ItemImageRestoreChange {
            let oldImageFileNames = [item.imageFileName, item.thumbnailFileName].compactMap { $0 }
            let restoredFiles = try restoredImageFiles()

            item.name = name
            item.category = category
            item.colorName = colorName
            item.season = season
            item.imageSymbol = imageSymbol
            item.imageFileName = restoredFiles?.imageFileName
            item.thumbnailFileName = restoredFiles?.thumbnailFileName
            item.imageData = nil
            item.thumbnailData = nil
            item.styleTagsText = styleTagsText
            item.notes = notes
            item.brand = normalizedOptional(brand)
            item.size = normalizedOptional(size)
            item.purchasePrice = purchasePrice
            item.purchaseDate = purchaseDate
            item.purchaseChannel = normalizedOptional(purchaseChannel)
            item.careNotes = normalizedOptional(careNotes)
            item.isFavorite = isFavorite
            item.importBatchID = importBatchID
            item.createdAt = createdAt
            item.updatedAt = updatedAt

            return ItemImageRestoreChange(
                oldFileNamesForCleanup: oldImageFileNames,
                newFileNamesForRollback: restoredFiles.fileNames
            )
        }

        private func normalizedOptional(_ text: String?) -> String? {
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private func restoredImageFiles() throws -> WardrobeStoredImageFiles? {
            try WardrobeImageStoragePreparer.storeImageFilesIfNeeded(
                itemID: id,
                imageData: imageData,
                thumbnailData: nil,
                fileNameTag: "restore-\(UUID().uuidString)"
            )
        }
    }

    struct OutfitRecord: Codable {
        let id: UUID
        let title: String
        let notes: String
        let presetTagsText: String?
        let createdAt: Date
        let updatedAt: Date?
        let isToday: Bool
        let sourceKind: String?
        let aiPrompt: String?
        let aiRecommendationReason: String?
        let aiWeatherSummary: String?
        let aiGeneratedAt: Date?
        let aiModelIdentifier: String?
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
            presetTagsText = outfit.presetTagsText
            createdAt = outfit.createdAt
            updatedAt = outfit.updatedAt
            isToday = outfit.isToday
            sourceKind = outfit.sourceKind
            aiPrompt = outfit.aiPrompt
            aiRecommendationReason = outfit.aiRecommendationReason
            aiWeatherSummary = outfit.aiWeatherSummary
            aiGeneratedAt = outfit.aiGeneratedAt
            aiModelIdentifier = outfit.aiModelIdentifier
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
                presetTagsText: presetTagsText ?? "",
                createdAt: createdAt,
                updatedAt: updatedAt,
                isToday: isToday,
                sourceKind: sourceKind ?? OOTDSourceKind.manual.rawValue,
                aiPrompt: aiPrompt,
                aiRecommendationReason: aiRecommendationReason,
                aiWeatherSummary: aiWeatherSummary,
                aiGeneratedAt: aiGeneratedAt,
                aiModelIdentifier: aiModelIdentifier,
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
            outfit.presetTagsText = OOTDPresetTag.normalizedText(from: presetTagsText ?? "")
            outfit.createdAt = createdAt
            outfit.updatedAt = updatedAt
            outfit.isToday = isToday
            outfit.sourceKind = OOTDSourceKind.normalized(sourceKind).rawValue
            outfit.aiPrompt = OOTDSourceKind.optionalTrimmed(aiPrompt)
            outfit.aiRecommendationReason = OOTDSourceKind.optionalTrimmed(aiRecommendationReason)
            outfit.aiWeatherSummary = OOTDSourceKind.optionalTrimmed(aiWeatherSummary)
            outfit.aiGeneratedAt = aiGeneratedAt
            outfit.aiModelIdentifier = OOTDSourceKind.optionalTrimmed(aiModelIdentifier)
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
        let planKindRawValue: String?
        let date: Date
        let title: String
        let occasion: String
        let locationName: String?
        let weatherCityName: String?
        let notes: String
        let outfitSummary: String
        let reminderEnabled: Bool
        let reminderDate: Date?
        let createdAt: Date
        let updatedAt: Date?
        let linkedOutfitID: UUID?

        init(plan: OutfitPlan) {
            id = plan.id
            planKindRawValue = plan.planKindRawValue
            date = plan.date
            title = plan.title
            occasion = plan.occasion
            locationName = plan.locationName
            weatherCityName = plan.weatherCityName
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
                planKind: OutfitPlanKind.normalized(planKindRawValue),
                date: date,
                title: title,
                occasion: occasion,
                locationName: locationName ?? "",
                weatherCityName: weatherCityName ?? "",
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
            plan.planKind = OutfitPlanKind.normalized(planKindRawValue)
            plan.date = date
            plan.title = title
            plan.occasion = occasion
            plan.locationName = (locationName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            plan.weatherCityName = (weatherCityName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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
