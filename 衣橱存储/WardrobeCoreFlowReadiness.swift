import Foundation

struct WardrobeCoreFlowReadiness: Equatable {
    let itemCount: Int
    let topCount: Int
    let bottomCount: Int
    let onePieceCount: Int
    let outfitCount: Int

    var canCreateOOTD: Bool {
        (topCount > 0 && bottomCount > 0) || onePieceCount > 0
    }

    var canGenerateRecommendation: Bool {
        topCount > 0 && bottomCount > 0
    }

    var canCreatePlan: Bool {
        outfitCount > 0
    }

    var missingOOTDRequirementText: String {
        if onePieceCount > 0 {
            return "已有连衣裙/套装，可先保存一件式 OOTD；也可以继续补齐上装和下装。"
        }

        switch (topCount == 0, bottomCount == 0) {
        case (true, true):
            return "至少需要 1 件上装和 1 件下装/裙装，或 1 件连衣裙/套装。"
        case (true, false):
            return "还缺 1 件上装；如果是连衣裙/套装，也可以直接作为一件式搭配。"
        case (false, true):
            return "还缺 1 件下装、裙装、连衣裙或套装。"
        case (false, false):
            return "已具备创建 OOTD 的基础单品。"
        }
    }

    var ootdBlockedTitle: String {
        itemCount == 0 ? "先添加衣物" : "还不能创建 OOTD"
    }

    var ootdBlockedMessage: String {
        if itemCount == 0 {
            return "先往衣橱里添加上装和下装/裙装，再回来保存第一套 OOTD。"
        }
        return "\(missingOOTDRequirementText)补齐后就可以保存搭配。"
    }

    var recommendationReadyMessage: String {
        return "已具备推荐基础：\(topCount) 件上装、\(bottomCount) 件下装/裙装。"
    }

    var recommendationBlockedTitle: String {
        itemCount == 0 ? "先添加衣物" : "暂时不能推荐"
    }

    var recommendationBlockedMessage: String {
        if itemCount == 0 {
            return "推荐至少需要 1 件上装和 1 件下装/裙装。先添加几件常穿单品后再生成。"
        }
        if onePieceCount > 0, topCount == 0 || bottomCount == 0 {
            return "一件式单品可以先手动保存 OOTD；智能推荐还需要至少 1 件上装和 1 件下装/裙装。"
        }
        return "\(missingOOTDRequirementText)补齐后就可以按天气和场景生成推荐。"
    }

    var planBlockedTitle: String {
        canCreateOOTD ? "先保存一套 OOTD" : "先补齐衣物"
    }

    var planBlockedMessage: String {
        if canCreateOOTD {
            return "穿搭计划需要绑定已保存的 OOTD。先创建一套搭配，再安排日期和提醒。"
        }
        return "创建计划前需要先有可保存的 OOTD。\(missingOOTDRequirementText)"
    }

    static func make(items: [WardrobeItem], outfits: [OOTDOutfit]) -> WardrobeCoreFlowReadiness {
        WardrobeCoreFlowReadiness(
            itemCount: items.count,
            topCount: items.filter { topCategories.contains($0.category) }.count,
            bottomCount: items.filter { bottomCategories.contains($0.category) }.count,
            onePieceCount: items.filter { onePieceCategories.contains($0.category) }.count,
            outfitCount: outfits.count
        )
    }

    private static let topCategories = Set(WardrobeCategory.topSlotRawValues)
    private static let bottomCategories = Set(WardrobeCategory.lowerBodyRawValues)
    private static let onePieceCategories = Set(WardrobeCategory.onePieceRawValues)
}
