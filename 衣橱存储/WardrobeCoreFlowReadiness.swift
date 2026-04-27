import Foundation

struct WardrobeCoreFlowReadiness: Equatable {
    let itemCount: Int
    let topCount: Int
    let bottomCount: Int
    let outfitCount: Int

    var canCreateOOTD: Bool {
        topCount > 0 && bottomCount > 0
    }

    var canGenerateRecommendation: Bool {
        canCreateOOTD
    }

    var canCreatePlan: Bool {
        outfitCount > 0
    }

    var missingOOTDRequirementText: String {
        switch (topCount == 0, bottomCount == 0) {
        case (true, true):
            "至少需要 1 件上装和 1 件下装/裙装。"
        case (true, false):
            "还缺 1 件上装。"
        case (false, true):
            "还缺 1 件下装或裙装。"
        case (false, false):
            "已具备创建 OOTD 的基础单品。"
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
        "已具备推荐基础：\(topCount) 件上装、\(bottomCount) 件下装/裙装。"
    }

    var recommendationBlockedTitle: String {
        itemCount == 0 ? "先添加衣物" : "暂时不能推荐"
    }

    var recommendationBlockedMessage: String {
        if itemCount == 0 {
            return "推荐至少需要 1 件上装和 1 件下装/裙装。先添加几件常穿单品后再生成。"
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
            outfitCount: outfits.count
        )
    }

    private static let topCategories: Set<String> = [
        WardrobeCategory.top.rawValue
    ]

    private static let bottomCategories: Set<String> = [
        WardrobeCategory.bottom.rawValue,
        WardrobeCategory.skirt.rawValue
    ]
}
