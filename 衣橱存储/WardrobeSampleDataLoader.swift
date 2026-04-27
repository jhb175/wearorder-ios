import SwiftData

struct WardrobeSampleDataSummary {
    let itemCount: Int
    let outfitCount: Int
    let planCount: Int
}

@MainActor
enum WardrobeSampleDataLoader {
    @discardableResult
    static func insertSampleData(into context: ModelContext) -> WardrobeSampleDataSummary {
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
            context.insert(inserted)
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
            context.insert(insertedOutfit)
            insertedOutfits[outfit.title] = insertedOutfit
        }

        for plan in WardrobeMockData.plans {
            context.insert(
                OutfitPlan(
                    date: plan.date,
                    title: plan.title,
                    occasion: plan.occasion,
                    notes: plan.notes,
                    outfitSummary: plan.outfitSummary,
                    reminderEnabled: false,
                    reminderDate: nil,
                    linkedOutfit: plan.linkedOutfitTitle.flatMap { insertedOutfits[$0] }
                )
            )
        }

        return WardrobeSampleDataSummary(
            itemCount: WardrobeMockData.items.count,
            outfitCount: WardrobeMockData.outfits.count,
            planCount: WardrobeMockData.plans.count
        )
    }
}
