import Foundation
import SwiftData

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
