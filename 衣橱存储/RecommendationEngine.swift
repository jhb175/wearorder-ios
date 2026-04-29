import Foundation

struct RecommendationInput: Equatable {
    var weather: RecommendationWeather?
    var temperatureCelsius: Int? = nil
    var occasion: RecommendationOccasion = .commute
    var style: RecommendationStyle = .relaxed
}

enum RecommendationWeather: String, CaseIterable, Identifiable {
    case sunny = "晴天"
    case partlyCloudy = "多云"
    case overcast = "阴天"
    case drizzle = "小雨"
    case heavyRain = "大雨"
    case thunderstorm = "雷雨"
    case windy = "大风"
    case snow = "下雪"

    var id: String { rawValue }
}

enum RecommendationOccasion: String, CaseIterable, Identifiable {
    case commute = "通勤"
    case casual = "休闲"
    case date = "约会"
    case travel = "出行"
    case indoor = "室内"

    var id: String { rawValue }
}

enum RecommendationStyle: String, CaseIterable, Identifiable {
    case relaxed = "轻松"
    case minimal = "简洁"
    case formal = "正式"
    case comfortable = "舒适"
    case layered = "层次感"

    var id: String { rawValue }
}

struct RecommendationResult: Identifiable {
    let id = UUID()
    let input: RecommendationInput
    let title: String
    let reasonSummary: String
    let topItem: WardrobeItem
    let bottomItem: WardrobeItem
    let outerwearItem: WardrobeItem?
    let shoesItem: WardrobeItem?
    let bagItem: WardrobeItem?
    let accessoryItem: WardrobeItem?
    let createdAt: Date
    let scoreHighlights: [String]
    let insights: [RecommendationInsight]
    let replacements: [RecommendationReplacement]
    let upgradeTips: [RecommendationUpgradeTip]

    var orderedItems: [WardrobeItem] {
        [topItem, bottomItem, outerwearItem, shoesItem, bagItem, accessoryItem].compactMap { $0 }
    }

    var subtitle: String {
        orderedItems.map(\.name).joined(separator: " + ")
    }

    var usesFavorite: Bool {
        orderedItems.contains(where: \.isFavorite)
    }
}

struct RecommendationResponse {
    let input: RecommendationInput
    let adjustment: RecommendationAdjustment?
    let results: [RecommendationResult]
    let emptyStateMessage: String?
    let wardrobeGaps: [RecommendationWardrobeGap]
}

struct RecommendationInsight: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
}

struct RecommendationReplacement: Identifiable {
    let id: String
    let slotTitle: String
    let currentItemName: String
    let replacementItem: WardrobeItem
    let reason: String
    let systemImage: String
}

struct RecommendationUpgradeTip: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
}

struct RecommendationWardrobeGap: Identifiable, Hashable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
}

enum RecommendationAdjustment: String, CaseIterable, Identifiable {
    case moreFormal = "更正式一点"
    case moreRelaxed = "更轻松一点"
    case warmer = "更保暖一点"
    case moreMinimal = "更简洁一点"

    var id: String { rawValue }
}

enum RecommendationEngine {
    static func generateRecommendations(
        from items: [WardrobeItem],
        input: RecommendationInput,
        adjustment: RecommendationAdjustment? = nil
    ) -> RecommendationResponse {
        let availableItems = items
        let wardrobeGaps = wardrobeGapHints(from: availableItems, input: input)
        let topPool = sortedCandidates(for: WardrobeCategory.topSlotRawValues, from: availableItems, input: input)
        let bottomPool = sortedCandidates(for: WardrobeCategory.lowerBodyRawValues, from: availableItems, input: input)

        guard !topPool.isEmpty, !bottomPool.isEmpty else {
            let message: String
            if topPool.isEmpty && bottomPool.isEmpty {
                message = "当前衣橱缺少上装和下装，暂时无法生成完整搭配。"
            } else if topPool.isEmpty {
                message = "当前衣橱缺少可用上装，先补录一些上装后再试。"
            } else {
                message = "当前衣橱缺少可用下装，先补录一些下装或裙装后再试。"
            }

            return RecommendationResponse(input: input, adjustment: adjustment, results: [], emptyStateMessage: message, wardrobeGaps: wardrobeGaps)
        }

        let outerwearPool = sortedCandidates(for: WardrobeCategory.outerwearRawValues, from: availableItems, input: input)
        let shoesPool = sortedCandidates(for: WardrobeCategory.shoesRawValues, from: availableItems, input: input)
        let bagPool = sortedCandidates(for: WardrobeCategory.bagRawValues, from: availableItems, input: input)
        let accessoryPool = sortedCandidates(for: WardrobeCategory.accessoryRawValues, from: availableItems, input: input)
        let candidatePools = RecommendationCandidatePools(
            topPool: topPool,
            bottomPool: bottomPool,
            outerwearPool: outerwearPool,
            shoesPool: shoesPool,
            bagPool: bagPool,
            accessoryPool: accessoryPool
        )

        let topCandidates = Array(topPool.prefix(5))
        let bottomCandidates = Array(bottomPool.prefix(5))
        let outerwearCandidates = shouldIncludeOuterwear(for: input, adjustment: adjustment)
        ? Array(outerwearPool.prefix(3))
        : []
        let shoesCandidates = Array(shoesPool.prefix(3))
        let bagCandidates = Array(bagPool.prefix(3))
        let accessoryCandidates = Array(accessoryPool.prefix(3))

        var candidateOutfits: [CandidateOutfit] = []
        var seenKeys = Set<String>()

        for top in topCandidates {
            for bottom in bottomCandidates where top.id != bottom.id {
                let optionalOuterwears: [WardrobeItem?] = outerwearCandidates.isEmpty ? [nil] : [nil] + outerwearCandidates.map { Optional($0) }
                let optionalShoes: [WardrobeItem?] = shoesCandidates.isEmpty ? [nil] : shoesCandidates.map { Optional($0) }
                let optionalBags: [WardrobeItem?] = bagCandidates.isEmpty ? [nil] : [nil] + bagCandidates.map { Optional($0) }
                let optionalAccessories: [WardrobeItem?] = accessoryCandidates.isEmpty ? [nil] : [nil] + accessoryCandidates.map { Optional($0) }

                for outerwear in optionalOuterwears {
                    for shoes in optionalShoes {
                        for bag in optionalBags {
                            for accessory in optionalAccessories {
                                let key = [
                                    top.id.uuidString,
                                    bottom.id.uuidString,
                                    outerwear?.id.uuidString ?? "nil",
                                    shoes?.id.uuidString ?? "nil",
                                    bag?.id.uuidString ?? "nil",
                                    accessory?.id.uuidString ?? "nil"
                                ].joined(separator: "|")

                                guard seenKeys.insert(key).inserted else { continue }

                                let candidate = CandidateOutfit(
                                    topItem: top,
                                    bottomItem: bottom,
                                    outerwearItem: outerwear,
                                    shoesItem: shoes,
                                    bagItem: bag,
                                    accessoryItem: accessory,
                                    score: combinationScore(
                                        top: top,
                                        bottom: bottom,
                                        outerwear: outerwear,
                                        shoes: shoes,
                                        bag: bag,
                                        accessory: accessory,
                                        input: input,
                                        adjustment: adjustment
                                    )
                                )

                                if candidate.score > 0 {
                                    candidateOutfits.append(candidate)
                                }
                            }
                        }
                    }
                }
            }
        }

        var selectedCandidates: [CandidateOutfit] = []
        let targetCount = min(3, max(1, candidateOutfits.count))

        while selectedCandidates.count < targetCount {
            let nextCandidate = candidateOutfits
                .filter { candidate in
                    !selectedCandidates.contains { $0.identityKey == candidate.identityKey }
                }
                .max { lhs, rhs in
                    diversifiedScore(for: lhs, selected: selectedCandidates) < diversifiedScore(for: rhs, selected: selectedCandidates)
                }

            guard let nextCandidate else { break }
            selectedCandidates.append(nextCandidate)
        }

        let results = selectedCandidates.enumerated().map { index, candidate in
            let usedFavorites = candidate.items.filter(\.isFavorite)
            let colorScore = colorHarmonyScore(for: candidate.items)
            let completenessScore = outfitCompletenessScore(
                shoes: candidate.shoesItem,
                bag: candidate.bagItem,
                accessory: candidate.accessoryItem,
                input: input,
                adjustment: adjustment
            )
            return RecommendationResult(
                input: input,
                title: recommendationTitle(input: input, adjustment: adjustment, index: index),
                reasonSummary: reasonSummary(
                    input: input,
                    favoritesCount: usedFavorites.count,
                    includesOuterwear: candidate.outerwearItem != nil,
                    occasionFitScore: occasionFitScore(for: candidate.items, input: input),
                    styleFitScore: styleFitScore(for: candidate.items, input: input),
                    colorHarmonyScore: colorScore,
                    completenessScore: completenessScore,
                    adjustment: adjustment
                ),
                topItem: candidate.topItem,
                bottomItem: candidate.bottomItem,
                outerwearItem: candidate.outerwearItem,
                shoesItem: candidate.shoesItem,
                bagItem: candidate.bagItem,
                accessoryItem: candidate.accessoryItem,
                createdAt: .now,
                scoreHighlights: scoreHighlights(
                    candidate: candidate,
                    input: input,
                    favoritesCount: usedFavorites.count,
                    occasionFitScore: occasionFitScore(for: candidate.items, input: input),
                    styleFitScore: styleFitScore(for: candidate.items, input: input),
                    colorHarmonyScore: colorScore,
                    completenessScore: completenessScore,
                    adjustment: adjustment
                ),
                insights: recommendationInsights(
                    candidate: candidate,
                    input: input,
                    colorHarmonyScore: colorScore,
                    completenessScore: completenessScore
                ),
                replacements: replacementSuggestions(
                    for: candidate,
                    pools: candidatePools,
                    input: input
                ),
                upgradeTips: upgradeTips(
                    for: candidate,
                    input: input,
                    colorHarmonyScore: colorScore,
                    completenessScore: completenessScore,
                    wardrobeGaps: wardrobeGaps
                )
            )
        }

        if results.isEmpty {
            return RecommendationResponse(
                input: input,
                adjustment: adjustment,
                results: [],
                emptyStateMessage: "当前衣橱数据不足以生成稳定的推荐，请补录更多单品后再试。",
                wardrobeGaps: wardrobeGaps
            )
        }

        return RecommendationResponse(input: input, adjustment: adjustment, results: results, emptyStateMessage: nil, wardrobeGaps: wardrobeGaps)
    }

    private static func sortedCandidates(
        for categories: [String],
        from items: [WardrobeItem],
        input: RecommendationInput
    ) -> [WardrobeItem] {
        items
            .filter { categories.contains($0.category) }
            .sorted {
                let lhs = score(for: $0, input: input, adjustment: nil)
                let rhs = score(for: $1, input: input, adjustment: nil)
                if lhs == rhs {
                    return $0.createdAt > $1.createdAt
                }
                return lhs > rhs
            }
    }

    private static func score(for item: WardrobeItem, input: RecommendationInput, adjustment: RecommendationAdjustment?) -> Int {
        var total = 10
        total += seasonScore(for: item, input: input)
        total += temperatureScore(for: item, input: input)
        total += styleScore(for: item, input: input)
        if item.isFavorite {
            total += 3
        }
        total += adjustmentScore(for: item, adjustment: adjustment)
        return total
    }

    private static func seasonScore(for item: WardrobeItem, input: RecommendationInput) -> Int {
        let preferredSeasons: Set<String>

        switch input.weather {
        case .sunny, .partlyCloudy:
            preferredSeasons = ["四季", "春夏", "春秋"]
        case .overcast, .windy:
            preferredSeasons = ["四季", "春秋", "秋冬"]
        case .drizzle, .heavyRain, .thunderstorm, .snow:
            preferredSeasons = ["四季", "春秋", "秋冬"]
        case .none:
            return 2
        }

        if preferredSeasons.contains(item.season) {
            return item.season == "四季" ? 2 : 4
        }

        if input.weather == .snow, item.season == "春夏" {
            return -6
        }

        return -4
    }

    private static func temperatureScore(for item: WardrobeItem, input: RecommendationInput) -> Int {
        guard let temperature = input.temperatureCelsius else { return 0 }

        switch temperature {
        case ...12:
            if item.season == "秋冬" { return 6 }
            if item.season == "春秋" || item.season == "四季" { return 3 }
            return -8
        case 13...18:
            if item.season == "秋冬" || item.season == "春秋" { return 4 }
            if item.season == "四季" { return 2 }
            return -4
        case 19...25:
            if item.season == "春秋" || item.season == "四季" { return 3 }
            return item.season == "春夏" ? 1 : -2
        case 26...:
            if item.season == "春夏" { return 5 }
            if item.season == "四季" { return 2 }
            return -6
        default:
            return 0
        }
    }

    private static func styleScore(for item: WardrobeItem, input: RecommendationInput) -> Int {
        let tags = item.styleTags.map { $0.lowercased() }
        let keywords = styleKeywords(for: input.style) + occasionKeywords(for: input.occasion)
        let matchCount = keywords.filter { keyword in
            tags.contains { $0.contains(keyword) }
        }.count
        return matchCount * 2
    }

    private static func styleKeywords(for style: RecommendationStyle) -> [String] {
        switch style {
        case .relaxed:
            ["轻松", "松弛", "休闲"]
        case .minimal:
            ["简洁", "极简", "干净"]
        case .formal:
            ["正式", "通勤", "利落"]
        case .comfortable:
            ["舒适", "柔软", "轻盈"]
        case .layered:
            ["层次", "叠穿", "外搭"]
        }
    }

    private static func occasionKeywords(for occasion: RecommendationOccasion) -> [String] {
        switch occasion {
        case .commute:
            ["通勤", "正式", "简洁"]
        case .casual:
            ["休闲", "舒适", "轻松"]
        case .date:
            ["精致", "轻甜", "有亮点"]
        case .travel:
            ["舒适", "轻便", "出行"]
        case .indoor:
            ["轻盈", "简洁", "舒适"]
        }
    }

    private static func shouldIncludeOuterwear(for input: RecommendationInput, adjustment: RecommendationAdjustment? = nil) -> Bool {
        if adjustment == .warmer {
            return true
        }
        if let temperature = input.temperatureCelsius {
            if temperature <= 18 { return true }
            if temperature >= 28, input.weather != .thunderstorm, input.weather != .heavyRain {
                return input.style == .layered
            }
        }
        switch input.weather {
        case .overcast, .drizzle, .heavyRain, .thunderstorm, .windy, .snow:
            return true
        case .sunny, .partlyCloudy:
            return input.style == .layered || input.style == .formal
        case .none:
            return input.style == .layered || input.style == .formal
        }
    }

    private static func reasonSummary(
        input: RecommendationInput,
        favoritesCount: Int,
        includesOuterwear: Bool,
        occasionFitScore: Int,
        styleFitScore: Int,
        colorHarmonyScore: Int,
        completenessScore: Int,
        adjustment: RecommendationAdjustment?
    ) -> String {
        var parts: [String] = []
        if let weather = input.weather {
            parts.append(weatherReasonText(for: weather, occasion: input.occasion))
        } else {
            parts.append("优先适配\(input.occasion.rawValue)场景")
        }
        if let temperature = input.temperatureCelsius {
            parts.append("按 \(temperature)° 调整厚薄")
        }
        parts.append(occasionFitScore >= 4 ? "更贴近\(input.occasion.rawValue)场景" : "兼顾\(input.occasion.rawValue)需求")
        parts.append(styleFitScore >= 4 ? "风格更偏\(input.style.rawValue)" : "保留\(input.style.rawValue)倾向")
        if includesOuterwear {
            parts.append("加入了更适合当前天气的外层单品")
        }
        if colorHarmonyScore >= 6 {
            parts.append("颜色组合更统一")
        } else if colorHarmonyScore >= 3 {
            parts.append("颜色关系比较稳妥")
        }
        if completenessScore >= 6 {
            parts.append("鞋包配饰更完整")
        }
        if favoritesCount > 0 {
            parts.append("优先使用了你的收藏单品")
        }
        if let adjustment {
            parts.append(adjustmentReasonText(for: adjustment))
        }
        return parts.joined(separator: "，")
    }

    private static func scoreHighlights(
        candidate: CandidateOutfit,
        input: RecommendationInput,
        favoritesCount: Int,
        occasionFitScore: Int,
        styleFitScore: Int,
        colorHarmonyScore: Int,
        completenessScore: Int,
        adjustment: RecommendationAdjustment?
    ) -> [String] {
        var highlights: [String] = []

        if let temperature = input.temperatureCelsius {
            let seasons = Set(candidate.items.map(\.season))
            if temperature >= 26, seasons.contains("春夏") {
                highlights.append("适合偏热天气")
            } else if temperature <= 18, !seasons.contains("春夏") {
                highlights.append("厚薄更稳")
            } else {
                highlights.append("温度已纳入")
            }
        }

        if occasionFitScore >= 4 {
            highlights.append("\(input.occasion.rawValue)命中")
        }

        if styleFitScore >= 4 {
            highlights.append("\(input.style.rawValue)风格")
        }

        if colorHarmonyScore >= 6 {
            highlights.append("颜色协调")
        }

        if completenessScore >= 6 {
            highlights.append("鞋包完整")
        }

        if favoritesCount > 0 {
            highlights.append("含收藏")
        }

        if let adjustment {
            highlights.append(adjustment.rawValue)
        }

        return Array(highlights.prefix(4))
    }

    private static func recommendationInsights(
        candidate: CandidateOutfit,
        input: RecommendationInput,
        colorHarmonyScore: Int,
        completenessScore: Int
    ) -> [RecommendationInsight] {
        var insights: [RecommendationInsight] = []

        if let weather = input.weather {
            insights.append(
                RecommendationInsight(
                    id: "weather",
                    title: "天气",
                    message: weatherReasonText(for: weather, occasion: input.occasion),
                    systemImage: "cloud.sun"
                )
            )
        }

        if let temperature = input.temperatureCelsius {
            let temperatureMessage: String
            if temperature >= 26 {
                temperatureMessage = "当前偏热，优先轻薄或四季单品。"
            } else if temperature <= 12 {
                temperatureMessage = "当前偏冷，优先保暖和层次。"
            } else {
                temperatureMessage = "当前温度适中，优先平衡厚薄。"
            }
            insights.append(
                RecommendationInsight(
                    id: "temperature",
                    title: "温度",
                    message: temperatureMessage,
                    systemImage: "thermometer.medium"
                )
            )
        }

        insights.append(
            RecommendationInsight(
                id: "occasion",
                title: "场景",
                message: "按\(input.occasion.rawValue)场景匹配衣物标签和单品完整度。",
                systemImage: "tag"
            )
        )

        insights.append(
            RecommendationInsight(
                id: "style",
                title: "风格",
                message: "优先选择更接近\(input.style.rawValue)的风格标签。",
                systemImage: "sparkles"
            )
        )

        let missingSlots = missingOptionalSlots(candidate: candidate)
        if missingSlots.isEmpty {
            insights.append(
                RecommendationInsight(
                    id: "complete",
                    title: "完整度",
                    message: completenessScore >= 6 ? "鞋包配饰较完整，可以直接保存为 OOTD。" : "基础单品已完整，可按需要继续微调。",
                    systemImage: "checkmark.circle"
                )
            )
        } else {
            insights.append(
                RecommendationInsight(
                    id: "missing-slots",
                    title: "可补充",
                    message: "还可以补充\(missingSlots.joined(separator: "、"))，让计划和展示更完整。",
                    systemImage: "plus.circle"
                )
            )
        }

        if colorHarmonyScore >= 6 {
            insights.append(
                RecommendationInsight(
                    id: "color",
                    title: "颜色",
                    message: "当前组合的颜色关系较统一。",
                    systemImage: "paintpalette"
                )
            )
        }

        return Array(insights.prefix(5))
    }

    private static func replacementSuggestions(
        for candidate: CandidateOutfit,
        pools: RecommendationCandidatePools,
        input: RecommendationInput
    ) -> [RecommendationReplacement] {
        var suggestions: [RecommendationReplacement] = []
        let usedIDs = Set(candidate.items.map(\.id))

        func addSuggestion(
            slotTitle: String,
            currentItem: WardrobeItem?,
            pool: [WardrobeItem],
            systemImage: String
        ) {
            guard let replacement = pool.first(where: { item in
                if let currentItem, item.id == currentItem.id {
                    return false
                }
                return !usedIDs.contains(item.id)
            }) else {
                return
            }

            let displaySlotTitle = currentItem == nil ? "\(slotTitle)补位" : "\(slotTitle)替换"
            suggestions.append(
                RecommendationReplacement(
                    id: "\(displaySlotTitle)-\(replacement.id.uuidString)",
                    slotTitle: displaySlotTitle,
                    currentItemName: currentItem?.name ?? "暂未选择",
                    replacementItem: replacement,
                    reason: replacementReason(
                        slotTitle: slotTitle,
                        hasCurrentItem: currentItem != nil,
                        input: input
                    ),
                    systemImage: systemImage
                )
            )
        }

        addSuggestion(slotTitle: "上装", currentItem: candidate.topItem, pool: pools.topPool, systemImage: "tshirt")
        addSuggestion(slotTitle: "下装", currentItem: candidate.bottomItem, pool: pools.bottomPool, systemImage: "figure.stand")

        if candidate.outerwearItem != nil || shouldIncludeOuterwear(for: input) {
            addSuggestion(slotTitle: "外套", currentItem: candidate.outerwearItem, pool: pools.outerwearPool, systemImage: "jacket")
        }

        addSuggestion(slotTitle: "鞋履", currentItem: candidate.shoesItem, pool: pools.shoesPool, systemImage: "shoe.2")

        if candidate.bagItem != nil || [.commute, .date, .travel].contains(input.occasion) {
            addSuggestion(slotTitle: "包袋", currentItem: candidate.bagItem, pool: pools.bagPool, systemImage: "bag")
        }

        if candidate.accessoryItem != nil || [.commute, .date].contains(input.occasion) || input.style == .layered {
            addSuggestion(slotTitle: "配饰", currentItem: candidate.accessoryItem, pool: pools.accessoryPool, systemImage: "sparkles")
        }

        return Array(suggestions.prefix(4))
    }

    private static func replacementReason(
        slotTitle: String,
        hasCurrentItem: Bool,
        input: RecommendationInput
    ) -> String {
        if !hasCurrentItem {
            switch slotTitle {
            case "外套":
                return "天气或层次变化时可以补上外层，让这套更稳。"
            case "鞋履":
                return "补齐鞋履后，这套搭配可以直接进入 OOTD 或计划。"
            case "包袋":
                return "\(input.occasion.rawValue)场景补一个包袋，会让出门完整度更高。"
            case "配饰":
                return "加一点细节可以提升完成度，同时不改变主搭配。"
            default:
                return "可作为当前组合的补位单品。"
            }
        }

        switch slotTitle {
        case "上装", "下装":
            return "保留\(input.style.rawValue)方向，快速换出另一种主视觉。"
        case "外套":
            return "天气或室内外温差变化时，可用它调整层次。"
        case "鞋履":
            return "鞋履一换，整体正式度和出行感会马上变化。"
        case "包袋":
            return "用不同包袋调整实用性和场景感。"
        case "配饰":
            return "用细节改变精致度，同时保持主体搭配稳定。"
        default:
            return "可在不重做整套搭配的情况下替换。"
        }
    }

    private static func upgradeTips(
        for candidate: CandidateOutfit,
        input: RecommendationInput,
        colorHarmonyScore: Int,
        completenessScore: Int,
        wardrobeGaps: [RecommendationWardrobeGap]
    ) -> [RecommendationUpgradeTip] {
        var tips: [RecommendationUpgradeTip] = []

        if candidate.shoesItem == nil {
            tips.append(
                RecommendationUpgradeTip(
                    id: "add-shoes",
                    title: "补齐鞋履",
                    message: "缺少鞋履会影响出门完整度，建议先补录一双常穿鞋。",
                    systemImage: "shoe.2"
                )
            )
        }

        if candidate.bagItem == nil, [.commute, .date, .travel].contains(input.occasion) {
            tips.append(
                RecommendationUpgradeTip(
                    id: "add-bag",
                    title: "补一个包袋",
                    message: "\(input.occasion.rawValue)场景通常需要包袋，补录后推荐会更贴近日常使用。",
                    systemImage: "bag"
                )
            )
        }

        if candidate.accessoryItem == nil, [.commute, .date].contains(input.occasion) {
            tips.append(
                RecommendationUpgradeTip(
                    id: "add-accessory",
                    title: "加入配饰细节",
                    message: "配饰能提高完成度，尤其适合\(input.occasion.rawValue)和需要留照片的场景。",
                    systemImage: "sparkles"
                )
            )
        }

        if shouldIncludeOuterwear(for: input), candidate.outerwearItem == nil {
            tips.append(
                RecommendationUpgradeTip(
                    id: "add-outerwear",
                    title: "准备一件外层",
                    message: "当前条件更适合有外套参与，补录外套后雨天、降温和层次推荐会更稳定。",
                    systemImage: "jacket"
                )
            )
        }

        if colorHarmonyScore < 3 {
            tips.append(
                RecommendationUpgradeTip(
                    id: "neutral-color",
                    title: "增加中性色基础款",
                    message: "当前颜色关系偏跳，补几件黑白灰、米色或牛仔类单品会提高搭配成功率。",
                    systemImage: "paintpalette"
                )
            )
        }

        if completenessScore < 0, tips.isEmpty {
            tips.append(
                RecommendationUpgradeTip(
                    id: "complete-slots",
                    title: "补齐常用槽位",
                    message: "优先补录鞋、包或配饰，后续推荐会从基础组合变成完整穿搭。",
                    systemImage: "plus.circle"
                )
            )
        }

        let coveredGapIDs = Set(
            [
                candidate.shoesItem == nil ? "missing-shoes" : nil,
                candidate.bagItem == nil ? "missing-bag" : nil,
                shouldIncludeOuterwear(for: input) && candidate.outerwearItem == nil ? "missing-outerwear" : nil
            ].compactMap { $0 }
        )

        for gap in wardrobeGaps where tips.count < 3 && !coveredGapIDs.contains(gap.id) {
            tips.append(
                RecommendationUpgradeTip(
                    id: "gap-\(gap.id)",
                    title: gap.title,
                    message: gap.message,
                    systemImage: gap.systemImage
                )
            )
        }

        return Array(tips.prefix(3))
    }

    private static func missingOptionalSlots(candidate: CandidateOutfit) -> [String] {
        var slots: [String] = []
        if candidate.shoesItem == nil { slots.append("鞋子") }
        if candidate.bagItem == nil { slots.append("包") }
        if candidate.accessoryItem == nil { slots.append("配饰") }
        return slots
    }

    private static func wardrobeGapHints(
        from items: [WardrobeItem],
        input: RecommendationInput
    ) -> [RecommendationWardrobeGap] {
        var gaps: [RecommendationWardrobeGap] = []
        let categories = Set(items.map(\.category))

        if categories.isDisjoint(with: Set(WardrobeCategory.shoesRawValues)) {
            gaps.append(
                RecommendationWardrobeGap(
                    id: "missing-shoes",
                    title: "补录鞋履",
                    message: "没有鞋履时，推荐会缺少完整出门闭环。",
                    systemImage: "shoe.2"
                )
            )
        }

        if categories.isDisjoint(with: Set(WardrobeCategory.bagRawValues)), [.commute, .date, .travel].contains(input.occasion) {
            gaps.append(
                RecommendationWardrobeGap(
                    id: "missing-bag",
                    title: "补录包袋",
                    message: "\(input.occasion.rawValue)场景常需要包袋来提高完整度。",
                    systemImage: "bag"
                )
            )
        }

        if shouldIncludeOuterwear(for: input), categories.isDisjoint(with: Set(WardrobeCategory.outerwearRawValues)) {
            gaps.append(
                RecommendationWardrobeGap(
                    id: "missing-outerwear",
                    title: "补录外套",
                    message: "当前天气或风格更适合有外层单品参与。",
                    systemImage: "jacket"
                )
            )
        }

        let missingTagCount = items.filter(\.styleTags.isEmpty).count
        if missingTagCount > 0 {
            gaps.append(
                RecommendationWardrobeGap(
                    id: "missing-style-tags",
                    title: "补充风格标签",
                    message: "\(missingTagCount) 件衣物缺少风格标签，会降低场景和风格匹配精度。",
                    systemImage: "tag"
                )
            )
        }

        return Array(gaps.prefix(3))
    }

    private static func weatherReasonText(for weather: RecommendationWeather, occasion: RecommendationOccasion) -> String {
        switch weather {
        case .sunny:
            "更适合当前晴天的\(occasion.rawValue)场景"
        case .partlyCloudy:
            "考虑到当前多云，兼顾\(occasion.rawValue)的轻层次"
        case .overcast:
            "更适合当前阴天，保持\(occasion.rawValue)场景下的利落感"
        case .drizzle:
            "适合雨天\(occasion.rawValue)，优先更稳妥的单品组合"
        case .heavyRain:
            "考虑到当前有明显降雨，优先更适合通勤和外出的搭配"
        case .thunderstorm:
            "针对雷雨天气，优先更稳妥和有保护感的组合"
        case .windy:
            "考虑到当前有风，优先更适合\(occasion.rawValue)的搭配"
        case .snow:
            "适合下雪天气，优先保暖和层次更完整的组合"
        }
    }

    private static func recommendationTitle(
        input: RecommendationInput,
        adjustment: RecommendationAdjustment?,
        index: Int
    ) -> String {
        let suffix = adjustment?.rawValue.replacingOccurrences(of: "一点", with: "") ?? input.style.rawValue
        return "\(input.occasion.rawValue)\(suffix)搭配 \(index + 1)"
    }

    private static func combinationScore(
        top: WardrobeItem,
        bottom: WardrobeItem,
        outerwear: WardrobeItem?,
        shoes: WardrobeItem?,
        bag: WardrobeItem?,
        accessory: WardrobeItem?,
        input: RecommendationInput,
        adjustment: RecommendationAdjustment?
    ) -> Int {
        let items = [top, bottom, outerwear, shoes, bag, accessory].compactMap { $0 }
        var total = 0
        total += score(for: top, input: input, adjustment: adjustment)
        total += score(for: bottom, input: input, adjustment: adjustment)
        total += outerwear.map { score(for: $0, input: input, adjustment: adjustment) } ?? 0
        total += shoes.map { score(for: $0, input: input, adjustment: adjustment) } ?? 0
        total += bag.map { score(for: $0, input: input, adjustment: adjustment) } ?? 0
        total += accessory.map { score(for: $0, input: input, adjustment: adjustment) } ?? 0
        total += seasonCompatibilityScore(items)
        total += styleCoherenceScore(items, input: input)
        total += weatherPracticalityScore(items: items, includesOuterwear: outerwear != nil, input: input, adjustment: adjustment)
        total += occasionFitScore(for: items, input: input)
        total += colorHarmonyScore(for: items)
        total += outfitCompletenessScore(shoes: shoes, bag: bag, accessory: accessory, input: input, adjustment: adjustment)
        total += minimalPenalty(bag: bag, accessory: accessory, adjustment: adjustment)
        return total
    }

    private static func diversifiedScore(for candidate: CandidateOutfit, selected: [CandidateOutfit]) -> Int {
        var score = candidate.score
        for selectedCandidate in selected {
            if candidate.topItem.id == selectedCandidate.topItem.id {
                score -= 14
            }
            if candidate.bottomItem.id == selectedCandidate.bottomItem.id {
                score -= 14
            }
            let overlapCount = Set(candidate.items.map(\.id)).intersection(Set(selectedCandidate.items.map(\.id))).count
            score -= overlapCount * 4
        }
        return score
    }

    private static func adjustmentScore(for item: WardrobeItem, adjustment: RecommendationAdjustment?) -> Int {
        guard let adjustment else { return 0 }
        let tags = item.styleTags.map { $0.lowercased() }
        switch adjustment {
        case .moreFormal:
            return containsAny(tags, keywords: ["正式", "通勤", "利落", "简洁"]) ? 4 : 0
        case .moreRelaxed:
            return containsAny(tags, keywords: ["轻松", "休闲", "舒适", "松弛"]) ? 4 : 0
        case .warmer:
            return ["秋冬", "春秋", "四季"].contains(item.season) ? 4 : 0
        case .moreMinimal:
            return containsAny(tags, keywords: ["简洁", "极简", "干净", "基础"]) ? 4 : 0
        }
    }

    private static func seasonCompatibilityScore(_ items: [WardrobeItem]) -> Int {
        let seasons = Set(items.map(\.season))
        if seasons.contains("春夏"), seasons.contains("秋冬") {
            return -8
        }
        if seasons.contains("春夏"), seasons.contains("春秋"), seasons.count > 2 {
            return -2
        }
        return 4
    }

    private static func styleCoherenceScore(_ items: [WardrobeItem], input: RecommendationInput) -> Int {
        let fit = styleFitScore(for: items, input: input)
        if fit == 0 {
            return -3
        }
        return fit * 2
    }

    private static func weatherPracticalityScore(
        items: [WardrobeItem],
        includesOuterwear: Bool,
        input: RecommendationInput,
        adjustment: RecommendationAdjustment?
    ) -> Int {
        var total = 0
        if shouldIncludeOuterwear(for: input, adjustment: adjustment) {
            total += includesOuterwear ? 6 : -5
        }
        if let weather = input.weather, [.drizzle, .heavyRain, .thunderstorm, .windy, .snow].contains(weather) {
            if items.contains(where: { WardrobeCategory.shoesRawValues.contains($0.category) && ["秋冬", "春秋", "四季"].contains($0.season) }) {
                total += 3
            }
        }
        return total
    }

    private static func occasionFitScore(for items: [WardrobeItem], input: RecommendationInput) -> Int {
        let tags = items.flatMap(\.styleTags).map { $0.lowercased() }
        let keywords = occasionKeywords(for: input.occasion)
        return keywords.reduce(into: 0) { partialResult, keyword in
            if tags.contains(where: { $0.contains(keyword) }) {
                partialResult += 2
            }
        }
    }

    private static func styleFitScore(for items: [WardrobeItem], input: RecommendationInput) -> Int {
        let tags = items.flatMap(\.styleTags).map { $0.lowercased() }
        let keywords = styleKeywords(for: input.style)
        return keywords.reduce(into: 0) { partialResult, keyword in
            if tags.contains(where: { $0.contains(keyword) }) {
                partialResult += 2
            }
        }
    }

    private static func minimalPenalty(
        bag: WardrobeItem?,
        accessory: WardrobeItem?,
        adjustment: RecommendationAdjustment?
    ) -> Int {
        guard adjustment == .moreMinimal else { return 0 }
        if bag != nil && accessory != nil {
            return -4
        }
        return 2
    }

    private static func colorHarmonyScore(for items: [WardrobeItem]) -> Int {
        let families = Set(items.map { colorFamily(for: $0) })
        let nonNeutralFamilies = families.subtracting(["neutral", "unknown"])

        if nonNeutralFamilies.isEmpty {
            return 6
        }

        if nonNeutralFamilies.count == 1 {
            return families.contains("neutral") ? 8 : 5
        }

        if nonNeutralFamilies.count == 2 {
            let pair = Set(nonNeutralFamilies)
            let balancedPairs: Set<Set<String>> = [
                ["blue", "brown"],
                ["blue", "green"],
                ["red", "brown"],
                ["yellow", "brown"]
            ]
            return balancedPairs.contains(pair) ? 5 : 2
        }

        return nonNeutralFamilies.count >= 4 ? -5 : -2
    }

    private static func colorFamily(for item: WardrobeItem) -> String {
        let name = item.colorName
        if name.contains("白") || name.contains("黑") || name.contains("灰") || name.contains("米") || name.contains("奶油") || name.contains("炭") {
            return "neutral"
        }
        if name.contains("蓝") || name.contains("青") || name.contains("牛仔") {
            return "blue"
        }
        if name.contains("棕") || name.contains("咖") || name.contains("驼") || name.contains("焦糖") {
            return "brown"
        }
        if name.contains("绿") {
            return "green"
        }
        if name.contains("红") || name.contains("粉") || name.contains("紫") {
            return "red"
        }
        if name.contains("黄") || name.contains("金") || name.contains("橙") {
            return "yellow"
        }
        return "unknown"
    }

    private static func outfitCompletenessScore(
        shoes: WardrobeItem?,
        bag: WardrobeItem?,
        accessory: WardrobeItem?,
        input: RecommendationInput,
        adjustment: RecommendationAdjustment?
    ) -> Int {
        var total = 0

        if shoes == nil {
            total -= input.occasion == .indoor ? 2 : 8
        } else {
            total += input.occasion == .travel ? 5 : 3
        }

        if bag != nil {
            total += input.occasion == .travel ? 4 : 2
        } else if [.commute, .travel, .date].contains(input.occasion), adjustment != .moreMinimal {
            total -= 2
        }

        if accessory != nil {
            total += [.date, .commute].contains(input.occasion) ? 3 : 1
        }

        return total
    }

    private static func adjustmentReasonText(for adjustment: RecommendationAdjustment) -> String {
        switch adjustment {
        case .moreFormal:
            "这轮额外提高了正式感"
        case .moreRelaxed:
            "这轮额外提高了轻松舒适感"
        case .warmer:
            "这轮优先补强了保暖层次"
        case .moreMinimal:
            "这轮优先保留更简洁的组合"
        }
    }

    private static func containsAny(_ tags: [String], keywords: [String]) -> Bool {
        keywords.contains { keyword in
            tags.contains { $0.contains(keyword) }
        }
    }
}

private extension RecommendationEngine {
    struct RecommendationCandidatePools {
        let topPool: [WardrobeItem]
        let bottomPool: [WardrobeItem]
        let outerwearPool: [WardrobeItem]
        let shoesPool: [WardrobeItem]
        let bagPool: [WardrobeItem]
        let accessoryPool: [WardrobeItem]
    }

    struct CandidateOutfit {
        let topItem: WardrobeItem
        let bottomItem: WardrobeItem
        let outerwearItem: WardrobeItem?
        let shoesItem: WardrobeItem?
        let bagItem: WardrobeItem?
        let accessoryItem: WardrobeItem?
        let score: Int

        var items: [WardrobeItem] {
            [topItem, bottomItem, outerwearItem, shoesItem, bagItem, accessoryItem].compactMap { $0 }
        }

        var identityKey: String {
            [
                topItem.id.uuidString,
                bottomItem.id.uuidString,
                outerwearItem?.id.uuidString ?? "nil",
                shoesItem?.id.uuidString ?? "nil",
                bagItem?.id.uuidString ?? "nil",
                accessoryItem?.id.uuidString ?? "nil"
            ].joined(separator: "|")
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard !isEmpty, indices.contains(index) else { return nil }
        return self[index]
    }
}

extension HomeDashboardViewModel.WeatherKind {
    var recommendationWeather: RecommendationWeather? {
        switch self {
        case .sunny:
            .sunny
        case .partlyCloudy:
            .partlyCloudy
        case .overcast:
            .overcast
        case .drizzle:
            .drizzle
        case .heavyRain:
            .heavyRain
        case .thunderstorm:
            .thunderstorm
        case .windy:
            .windy
        case .snow:
            .snow
        }
    }
}
