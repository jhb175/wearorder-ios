import Foundation
import SwiftData
import SwiftUI

@Model
final class WardrobeItem {
    var id: UUID
    var name: String
    var category: String
    var colorName: String
    var season: String
    var imageSymbol: String
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var styleTagsText: String
    var notes: String
    var brand: String?
    var size: String?
    var purchasePrice: Double?
    var purchaseDate: Date?
    var purchaseChannel: String?
    var careNotes: String?
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        colorName: String,
        season: String,
        imageSymbol: String,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        styleTagsText: String = "",
        notes: String = "",
        brand: String = "",
        size: String = "",
        purchasePrice: Double? = nil,
        purchaseDate: Date? = nil,
        purchaseChannel: String = "",
        careNotes: String = "",
        isFavorite: Bool = false,
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
        self.styleTagsText = styleTagsText
        self.notes = notes
        self.brand = Self.optionalTrimmed(brand)
        self.size = Self.optionalTrimmed(size)
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.purchaseChannel = Self.optionalTrimmed(purchaseChannel)
        self.careNotes = Self.optionalTrimmed(careNotes)
        self.isFavorite = isFavorite
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
    var id: UUID
    var date: Date
    var title: String
    var occasion: String
    var notes: String
    var outfitSummary: String
    var reminderEnabled: Bool
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date?
    var linkedOutfit: OOTDOutfit?

    init(
        id: UUID = UUID(),
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
}

@Model
final class OOTDOutfit {
    var id: UUID
    var title: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date?
    var isToday: Bool
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
        self.topItem = topItem
        self.bottomItem = bottomItem
        self.outerwearItem = outerwearItem
        self.shoesItem = shoesItem
        self.bagItem = bagItem
        self.accessoryItem = accessoryItem
    }
}

enum WardrobeMockData {
    static let items: [WardrobeItem] = [
        WardrobeItem(name: "奶油白衬衫", category: "上装", colorName: "奶油白", season: "四季", imageSymbol: "shirt.fill", styleTagsText: "通勤, 极简", brand: "基础衣橱", size: "M", purchasePrice: 199, purchaseDate: Date(timeIntervalSince1970: 1_735_689_600), purchaseChannel: "线下门店", careNotes: "低温熨烫，浅色单独洗"),
        WardrobeItem(name: "雾蓝针织开衫", category: "外套", colorName: "雾蓝", season: "春秋", imageSymbol: "sparkles", styleTagsText: "层次, 温柔", brand: "Soft Knit", size: "M", purchasePrice: 269, purchaseDate: Date(timeIntervalSince1970: 1_741_132_800), purchaseChannel: "线上商城", careNotes: "平铺晾干，避免悬挂变形"),
        WardrobeItem(name: "炭灰西装裤", category: "下装", colorName: "炭灰", season: "四季", imageSymbol: "figure.walk", styleTagsText: "通勤, 正式", brand: "Daily Tailor", size: "28", purchasePrice: 329, purchaseDate: Date(timeIntervalSince1970: 1_738_368_000), purchaseChannel: "线下门店"),
        WardrobeItem(name: "黑色百褶裙", category: "裙装", colorName: "曜石黑", season: "春秋", imageSymbol: "sun.max.trianglebadge.exclamationmark", styleTagsText: "轻甜, 休闲", brand: "Weekend", size: "S", purchasePrice: 189, purchaseDate: Date(timeIntervalSince1970: 1_744_070_400), purchaseChannel: "线上商城"),
        WardrobeItem(name: "白色运动鞋", category: "鞋履", colorName: "暖白", season: "四季", imageSymbol: "shoe.2.fill", styleTagsText: "舒适, 休闲", brand: "Walk Lab", size: "38", purchasePrice: 399, purchaseDate: Date(timeIntervalSince1970: 1_732_924_800), purchaseChannel: "品牌官网", careNotes: "鞋面污渍及时擦拭"),
        WardrobeItem(name: "焦糖托特包", category: "包袋", colorName: "焦糖棕", season: "四季", imageSymbol: "bag.fill", styleTagsText: "通勤, 实用", brand: "Carry Daily", size: "中号", purchasePrice: 459, purchaseDate: Date(timeIntervalSince1970: 1_727_740_800), purchaseChannel: "线下门店"),
        WardrobeItem(name: "珍珠耳饰", category: "配饰", colorName: "珠光白", season: "四季", imageSymbol: "circle.hexagongrid.fill", styleTagsText: "精致, 轻甜", brand: "Tiny Shine", size: "均码", purchasePrice: 99, purchaseDate: Date(timeIntervalSince1970: 1_746_662_400), purchaseChannel: "线上商城"),
        WardrobeItem(name: "海军蓝棒球帽", category: "帽子", colorName: "海军蓝", season: "春夏", imageSymbol: "cap.fill", styleTagsText: "休闲, 运动", brand: "Sun Day", size: "均码", purchasePrice: 129, purchaseDate: Date(timeIntervalSince1970: 1_749_340_800), purchaseChannel: "品牌官网")
    ]

    static let plans: [OutfitPlanSeed] = [
        OutfitPlanSeed(
            date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
            title: "周二通勤",
            occasion: "办公室",
            notes: "开会前直接查看这套通勤搭配。",
            outfitSummary: "奶油白衬衫 + 炭灰西装裤 + 雾蓝针织开衫",
            reminderEnabled: true,
            reminderDate: Calendar.current.date(bySettingHour: 8, minute: 20, second: 0, of: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now),
            linkedOutfitTitle: "今日通勤搭配"
        ),
        OutfitPlanSeed(
            date: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now,
            title: "周三咖啡会面",
            occasion: "轻社交",
            notes: "轻松一点，但保持干净利落。",
            outfitSummary: "黑色百褶裙 + 白色运动鞋 + 焦糖托特包",
            reminderEnabled: true,
            reminderDate: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now),
            linkedOutfitTitle: "周末咖啡搭配"
        ),
        OutfitPlanSeed(
            date: Calendar.current.date(byAdding: .day, value: 4, to: .now) ?? .now,
            title: "周五休闲日",
            occasion: "放松",
            notes: "留给轻松场景，不开提醒。",
            outfitSummary: "奶油白衬衫 + 白色运动鞋 + 海军蓝棒球帽",
            reminderEnabled: false,
            reminderDate: nil,
            linkedOutfitTitle: nil
        )
    ]

    static let outfits: [OOTDOutfitSeed] = [
        OOTDOutfitSeed(
            title: "今日通勤搭配",
            notes: "低饱和配色，适合工作日直接出门。",
            isToday: true,
            topName: "奶油白衬衫",
            bottomName: "炭灰西装裤",
            outerwearName: "雾蓝针织开衫",
            shoesName: "白色运动鞋",
            bagName: "焦糖托特包",
            accessoryName: "珍珠耳饰"
        ),
        OOTDOutfitSeed(
            title: "周末咖啡搭配",
            notes: "用裙装和帽子做一点轻松感。",
            isToday: false,
            topName: "奶油白衬衫",
            bottomName: "黑色百褶裙",
            outerwearName: nil,
            shoesName: "白色运动鞋",
            bagName: "焦糖托特包",
            accessoryName: "海军蓝棒球帽"
        )
    ]
}

struct OOTDOutfitSeed {
    let title: String
    let notes: String
    let isToday: Bool
    let topName: String?
    let bottomName: String?
    let outerwearName: String?
    let shoesName: String?
    let bagName: String?
    let accessoryName: String?
}

struct OutfitPlanSeed {
    let date: Date
    let title: String
    let occasion: String
    let notes: String
    let outfitSummary: String
    let reminderEnabled: Bool
    let reminderDate: Date?
    let linkedOutfitTitle: String?
}

enum WardrobePreviewContainer {
    static let shared: ModelContainer = make()

    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(
                for: WardrobeItem.self,
                OutfitPlan.self,
                OOTDOutfit.self,
                configurations: configuration
            )

            var insertedItems: [String: WardrobeItem] = [:]
            for item in WardrobeMockData.items {
                let inserted = WardrobeItem(
                    name: item.name,
                    category: item.category,
                    colorName: item.colorName,
                    season: item.season,
                    imageSymbol: item.imageSymbol,
                    styleTagsText: item.styleTagsText,
                    notes: item.notes,
                    brand: item.trimmedBrand ?? "",
                    size: item.trimmedSize ?? "",
                    purchasePrice: item.purchasePrice,
                    purchaseDate: item.purchaseDate,
                    purchaseChannel: item.trimmedPurchaseChannel ?? "",
                    careNotes: item.trimmedCareNotes ?? "",
                    isFavorite: item.isFavorite
                )
                container.mainContext.insert(inserted)
                insertedItems[item.name] = inserted
            }

            var insertedOutfits: [String: OOTDOutfit] = [:]
            for outfit in WardrobeMockData.outfits {
                let insertedOutfit = OOTDOutfit(
                    title: outfit.title,
                    notes: outfit.notes,
                    isToday: outfit.isToday,
                    topItem: outfit.topName.flatMap { insertedItems[$0] },
                    bottomItem: outfit.bottomName.flatMap { insertedItems[$0] },
                    outerwearItem: outfit.outerwearName.flatMap { insertedItems[$0] },
                    shoesItem: outfit.shoesName.flatMap { insertedItems[$0] },
                    bagItem: outfit.bagName.flatMap { insertedItems[$0] },
                    accessoryItem: outfit.accessoryName.flatMap { insertedItems[$0] }
                )
                container.mainContext.insert(insertedOutfit)
                insertedOutfits[outfit.title] = insertedOutfit
            }

            for plan in WardrobeMockData.plans {
                container.mainContext.insert(
                    OutfitPlan(
                        date: plan.date,
                        title: plan.title,
                        occasion: plan.occasion,
                        notes: plan.notes,
                        outfitSummary: plan.outfitSummary,
                        reminderEnabled: plan.reminderEnabled,
                        reminderDate: plan.reminderDate,
                        linkedOutfit: plan.linkedOutfitTitle.flatMap { insertedOutfits[$0] }
                    )
                )
            }

            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
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
        imageData == nil || styleTags.isEmpty || trimmedBrand == nil || trimmedSize == nil
    }

    var preferredThumbnailData: Data? {
        thumbnailData ?? imageData
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
