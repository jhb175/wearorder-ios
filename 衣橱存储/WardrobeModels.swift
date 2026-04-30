import Foundation
import SwiftData
import SwiftUI

@Model
final class WardrobeItem {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = "上装"
    var colorName: String = "未设置"
    var season: String = "四季"
    var imageSymbol: String = "tshirt.fill"
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var imageFileName: String?
    var thumbnailFileName: String?
    var styleTagsText: String = ""
    var notes: String = ""
    var brand: String?
    var size: String?
    var purchasePrice: Double?
    var purchaseDate: Date?
    var purchaseChannel: String?
    var careNotes: String?
    var isFavorite: Bool = false
    var importBatchID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date?
    @Relationship(inverse: \OOTDOutfit.topItem) var topOutfits: [OOTDOutfit]?
    @Relationship(inverse: \OOTDOutfit.bottomItem) var bottomOutfits: [OOTDOutfit]?
    @Relationship(inverse: \OOTDOutfit.outerwearItem) var outerwearOutfits: [OOTDOutfit]?
    @Relationship(inverse: \OOTDOutfit.shoesItem) var shoesOutfits: [OOTDOutfit]?
    @Relationship(inverse: \OOTDOutfit.bagItem) var bagOutfits: [OOTDOutfit]?
    @Relationship(inverse: \OOTDOutfit.accessoryItem) var accessoryOutfits: [OOTDOutfit]?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        colorName: String,
        season: String,
        imageSymbol: String,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        imageFileName: String? = nil,
        thumbnailFileName: String? = nil,
        styleTagsText: String = "",
        notes: String = "",
        brand: String = "",
        size: String = "",
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        purchaseChannel: String = "",
        careNotes: String = "",
        isFavorite: Bool = false,
        importBatchID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.colorName = colorName
        self.season = season
        self.imageSymbol = imageSymbol
        self.imageData = imageData
        self.thumbnailData = thumbnailData ?? imageData.flatMap { ImageDataOptimizer.thumbnailJPEGData(from: $0) }
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.styleTagsText = styleTagsText
        self.notes = notes
        self.brand = Self.optionalTrimmed(brand)
        self.size = Self.optionalTrimmed(size)
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.purchaseChannel = Self.optionalTrimmed(purchaseChannel)
        self.careNotes = Self.optionalTrimmed(careNotes)
        self.isFavorite = isFavorite
        self.importBatchID = importBatchID
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    private static func optionalTrimmed(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@Model
final class OutfitPlan {
    var id: UUID = UUID()
    var planKindRawValue: String? = OutfitPlanKind.daily.rawValue
    var date: Date = Date.now
    var title: String = ""
    var occasion: String = ""
    var notes: String = ""
    var outfitSummary: String = ""
    var reminderEnabled: Bool = false
    var reminderDate: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date?
    var linkedOutfit: OOTDOutfit?

    init(
        id: UUID = UUID(),
        planKind: OutfitPlanKind = .daily,
        date: Date,
        title: String,
        occasion: String,
        notes: String = "",
        outfitSummary: String,
        reminderEnabled: Bool,
        reminderDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        linkedOutfit: OOTDOutfit? = nil
    ) {
        self.id = id
        self.planKindRawValue = planKind.rawValue
        self.date = date
        self.title = title
        self.occasion = occasion
        self.notes = notes
        self.outfitSummary = outfitSummary
        self.reminderEnabled = reminderEnabled
        self.reminderDate = reminderDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.linkedOutfit = linkedOutfit
    }

    var planKind: OutfitPlanKind {
        get { OutfitPlanKind.normalized(planKindRawValue) }
        set { planKindRawValue = newValue.rawValue }
    }
}

@Model
final class OOTDOutfit {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date?
    var isToday: Bool = false
    var sourceKind: String = OOTDSourceKind.manual.rawValue
    var aiPrompt: String?
    var aiRecommendationReason: String?
    var aiWeatherSummary: String?
    var aiGeneratedAt: Date?
    var aiModelIdentifier: String?
    @Relationship(inverse: \OutfitPlan.linkedOutfit) var linkedPlans: [OutfitPlan]?
    var topItem: WardrobeItem?
    var bottomItem: WardrobeItem?
    var outerwearItem: WardrobeItem?
    var shoesItem: WardrobeItem?
    var bagItem: WardrobeItem?
    var accessoryItem: WardrobeItem?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        isToday: Bool = false,
        sourceKind: String = OOTDSourceKind.manual.rawValue,
        aiPrompt: String? = nil,
        aiRecommendationReason: String? = nil,
        aiWeatherSummary: String? = nil,
        aiGeneratedAt: Date? = nil,
        aiModelIdentifier: String? = nil,
        topItem: WardrobeItem? = nil,
        bottomItem: WardrobeItem? = nil,
        outerwearItem: WardrobeItem? = nil,
        shoesItem: WardrobeItem? = nil,
        bagItem: WardrobeItem? = nil,
        accessoryItem: WardrobeItem? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.isToday = isToday
        self.sourceKind = OOTDSourceKind.normalized(sourceKind).rawValue
        self.aiPrompt = OOTDSourceKind.optionalTrimmed(aiPrompt)
        self.aiRecommendationReason = OOTDSourceKind.optionalTrimmed(aiRecommendationReason)
        self.aiWeatherSummary = OOTDSourceKind.optionalTrimmed(aiWeatherSummary)
        self.aiGeneratedAt = aiGeneratedAt
        self.aiModelIdentifier = OOTDSourceKind.optionalTrimmed(aiModelIdentifier)
        self.topItem = topItem
        self.bottomItem = bottomItem
        self.outerwearItem = outerwearItem
        self.shoesItem = shoesItem
        self.bagItem = bagItem
        self.accessoryItem = accessoryItem
    }
}

enum OOTDSourceKind: String, CaseIterable {
    case manual
    case recommendation
    case ai

    var displayTitle: String {
        switch self {
        case .manual:
            return "手动创建"
        case .recommendation:
            return "轻量推荐"
        case .ai:
            return "AI 搭配师"
        }
    }

    static func normalized(_ rawValue: String?) -> OOTDSourceKind {
        guard let rawValue,
              let sourceKind = OOTDSourceKind(rawValue: rawValue) else {
            return .manual
        }
        return sourceKind
    }

    static func optionalTrimmed(_ text: String?) -> String? {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension WardrobeItem {
    var lastModifiedAt: Date {
        updatedAt ?? createdAt
    }

    var styleTags: [String] {
        styleTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var trimmedBrand: String? {
        Self.optionalTrimmed(brand)
    }

    var trimmedSize: String? {
        Self.optionalTrimmed(size)
    }

    var trimmedPurchaseChannel: String? {
        Self.optionalTrimmed(purchaseChannel)
    }

    var trimmedCareNotes: String? {
        Self.optionalTrimmed(careNotes)
    }

    var purchasePriceDisplayText: String? {
        guard let purchasePrice else { return nil }
        return purchasePrice.formatted(.currency(code: "CNY"))
    }

    var purchaseDetailLines: [String] {
        var lines: [String] = []
        if let trimmedBrand { lines.append("品牌：\(trimmedBrand)") }
        if let trimmedSize { lines.append("尺码：\(trimmedSize)") }
        if let purchasePriceDisplayText { lines.append("价格：\(purchasePriceDisplayText)") }
        if let purchaseDate { lines.append("购买日期：\(purchaseDate.formatted(.dateTime.year().month().day()))") }
        if let trimmedPurchaseChannel { lines.append("购买渠道：\(trimmedPurchaseChannel)") }
        return lines
    }

    var purchaseDetailText: String {
        let lines = purchaseDetailLines
        return lines.isEmpty ? "暂未填写" : lines.joined(separator: "\n")
    }

    var fullDisplaySubtitle: String {
        let base = "\(category) · \(colorName) · \(season)"
        guard let trimmedBrand else { return base }
        return "\(trimmedBrand) · \(base)"
    }

    var compactDisplaySubtitle: String {
        let base = "\(category) · \(colorName)"
        guard let trimmedBrand else { return base }
        return "\(trimmedBrand) · \(base)"
    }

    var needsDetailCompletion: Bool {
        !hasPhoto || styleTags.isEmpty || trimmedBrand == nil || trimmedSize == nil
    }

    var hasPhoto: Bool {
        imageFileName != nil || thumbnailFileName != nil || imageData != nil || thumbnailData != nil
    }

    var preferredThumbnailData: Data? {
        WardrobeImageFileStore.shared.data(for: thumbnailFileName) ?? thumbnailData
    }

    var displayImageData: Data? {
        WardrobeImageFileStore.shared.data(for: imageFileName) ?? imageData ?? preferredThumbnailData
    }

    var storedImageByteCount: Int {
        if let fileByteCount = WardrobeImageFileStore.shared.byteCount(for: imageFileName) {
            return fileByteCount
        }
        if let fileByteCount = WardrobeImageFileStore.shared.byteCount(for: thumbnailFileName) {
            return fileByteCount
        }
        return imageData?.count ?? 0
    }

    var storedImageFiles: WardrobeStoredImageFiles? {
        guard let imageFileName, let thumbnailFileName else { return nil }
        return WardrobeStoredImageFiles(imageFileName: imageFileName, thumbnailFileName: thumbnailFileName)
    }

    func applyStoredImageFiles(_ files: WardrobeStoredImageFiles, clearInlineData: Bool) {
        imageFileName = files.imageFileName
        thumbnailFileName = files.thumbnailFileName
        if clearInlineData {
            imageData = nil
            thumbnailData = nil
        }
    }

    var searchableFields: [String] {
        [name, category, colorName, season, styleTagsText, notes] +
        [trimmedBrand, trimmedSize, trimmedPurchaseChannel, trimmedCareNotes].compactMap { $0 }
    }

    var tintColor: Color {
        switch colorName {
        case "奶油白", "暖白", "珠光白":
            return Color(red: 0.96, green: 0.94, blue: 0.90)
        case "雾蓝", "海军蓝":
            return Color(red: 0.44, green: 0.58, blue: 0.77)
        case "炭灰", "曜石黑":
            return Color(red: 0.31, green: 0.33, blue: 0.38)
        case "焦糖棕":
            return Color(red: 0.67, green: 0.45, blue: 0.28)
        default:
            return Color.accentColor
        }
    }

    private static func optionalTrimmed(_ text: String?) -> String? {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension OOTDOutfit {
    var lastModifiedAt: Date {
        updatedAt ?? createdAt
    }

    var source: OOTDSourceKind {
        OOTDSourceKind.normalized(sourceKind)
    }

    var wasGeneratedByAI: Bool {
        source == .ai
    }

    var sourceDisplayTitle: String {
        source.displayTitle
    }

    var orderedItems: [WardrobeItem] {
        [topItem, bottomItem, outerwearItem, shoesItem, bagItem, accessoryItem].compactMap { $0 }
    }

    var isIncomplete: Bool {
        topItem == nil || bottomItem == nil
    }

    var missingSlotTitles: [String] {
        var slots: [String] = []
        if topItem == nil { slots.append("上装") }
        if bottomItem == nil { slots.append("下装") }
        if outerwearItem == nil { slots.append("外套") }
        if shoesItem == nil { slots.append("鞋子") }
        if bagItem == nil { slots.append("包") }
        if accessoryItem == nil { slots.append("配饰") }
        return slots
    }

    var summaryText: String {
        let names = orderedItems.map(\.name)
        return names.isEmpty ? "尚未选择单品" : names.joined(separator: " + ")
    }

    func removeReferences(to item: WardrobeItem) {
        if topItem?.id == item.id { topItem = nil }
        if bottomItem?.id == item.id { bottomItem = nil }
        if outerwearItem?.id == item.id { outerwearItem = nil }
        if shoesItem?.id == item.id { shoesItem = nil }
        if bagItem?.id == item.id { bagItem = nil }
        if accessoryItem?.id == item.id { accessoryItem = nil }
        updatedAt = .now
    }
}

extension OutfitPlan {
    var lastModifiedAt: Date {
        updatedAt ?? createdAt
    }
}
