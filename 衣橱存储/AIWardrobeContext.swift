import Foundation

/// Builds the candidate pool + serialized prompt body that gets handed
/// to the on-device language model. The class deliberately knows
/// nothing about FoundationModels — it only produces strings and
/// `[WardrobeItem]` collections, so it's fully unit-testable on every
/// iOS version.
///
/// 4K context budget is the hard constraint. To stay well under it we
/// (a) pre-filter items by slot + season, (b) cap each slot to 8
/// items, (c) cap the total to 35 items, (d) emit a compact line
/// format instead of JSON.
struct AIWardrobeContext: Equatable {

    /// Candidate items grouped by outfit slot. Each list is already
    /// truncated and ranked.
    let candidatesBySlot: [String: [WardrobeItem]]

    /// Original user prompt as typed.
    let userPrompt: String

    /// Weather context as it should appear in the final prompt.
    let weatherSummary: String

    /// Final composed prompt ready to send to `LanguageModelSession`.
    /// Contains weather, user intent, candidate inventory, and
    /// formatting rules. Instructions live separately on the session.
    let promptText: String

    /// Slot key strings. Stable; used as dictionary keys + display.
    static let slotKeys = ["top", "bottom", "outerwear", "shoes", "bag", "accessory"]

    /// Lookup by ID string emitted by the model.
    func item(matching idString: String) -> WardrobeItem? {
        let normalized = idString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let uuid = UUID(uuidString: normalized) else { return nil }
        for items in candidatesBySlot.values {
            if let match = items.first(where: { $0.id == uuid }) {
                return match
            }
        }
        return nil
    }

    /// Returns whether `item.id` belongs to the candidate list for the
    /// given slot key. Validator uses this to reject category/slot
    /// mismatches.
    func isCandidate(_ item: WardrobeItem, forSlotKey slotKey: String) -> Bool {
        candidatesBySlot[slotKey]?.contains(where: { $0.id == item.id }) ?? false
    }
}

// MARK: - Builder

enum AIWardrobeContextBuilder {

    static let maxPerSlot = 8
    static let maxTotal = 35

    static func build(
        userPrompt: String,
        weather: HomeDashboardViewModel.WeatherSnapshot?,
        season: ClothingSeason = .all,
        items: [WardrobeItem]
    ) -> AIWardrobeContext {
        let candidates = candidatesBySlot(items: items, season: season)
        let weatherSummary = composeWeatherSummary(weather)
        let promptText = composePromptText(
            userPrompt: userPrompt,
            weatherSummary: weatherSummary,
            candidatesBySlot: candidates
        )

        return AIWardrobeContext(
            candidatesBySlot: candidates,
            userPrompt: userPrompt,
            weatherSummary: weatherSummary,
            promptText: promptText
        )
    }

    // MARK: - Filter & rank

    private static func candidatesBySlot(
        items: [WardrobeItem],
        season: ClothingSeason
    ) -> [String: [WardrobeItem]] {
        let slotCategoryMap: [(String, [String])] = [
            ("top", WardrobeCategory.topSlotRawValues),
            ("bottom", WardrobeCategory.ootdBottomSlotRawValues),
            ("outerwear", WardrobeCategory.outerwearRawValues),
            ("shoes", WardrobeCategory.shoesRawValues),
            ("bag", WardrobeCategory.bagRawValues),
            ("accessory", WardrobeCategory.accessoryRawValues)
        ]

        var pools: [String: [WardrobeItem]] = [:]
        for (key, categoryRaws) in slotCategoryMap {
            let categorySet = Set(categoryRaws)
            let candidates = items
                .filter { categorySet.contains($0.category) }
                .filter { matchesSeason($0, currentSeason: season) }
                .sorted { ranking($0) > ranking($1) }
                .prefix(maxPerSlot)
            pools[key] = Array(candidates)
        }

        // Global cap: if pools sum > maxTotal, trim the largest slots
        // proportionally. Top + bottom always retain at least 4 entries.
        let total = pools.values.reduce(0) { $0 + $1.count }
        guard total > maxTotal else { return pools }

        var trimmed = pools
        let scale = Double(maxTotal) / Double(total)
        for key in trimmed.keys {
            let original = trimmed[key, default: []]
            let preserved = (key == "top" || key == "bottom") ? 4 : 2
            let target = max(preserved, Int((Double(original.count) * scale).rounded()))
            trimmed[key] = Array(original.prefix(target))
        }
        return trimmed
    }

    /// Item ranking: favorite first, then most-recently created.
    /// Designed to put the user's likely picks at the top of the
    /// candidate list — the LLM tends to favor early entries.
    private static func ranking(_ item: WardrobeItem) -> Int {
        var score = Int(item.createdAt.timeIntervalSince1970 / 60)
        if item.isFavorite { score += 1_000_000 }
        return score
    }

    private static func matchesSeason(
        _ item: WardrobeItem,
        currentSeason: ClothingSeason
    ) -> Bool {
        let itemSeason = ClothingSeason(rawValue: item.season) ?? .all
        if itemSeason == .all || currentSeason == .all { return true }
        return itemSeason == currentSeason
    }

    // MARK: - Prompt composition

    private static func composeWeatherSummary(
        _ weather: HomeDashboardViewModel.WeatherSnapshot?
    ) -> String {
        guard let weather else { return "天气未知" }
        var parts: [String] = []
        parts.append("\(weather.kind.rawValue) \(weather.temperature)°C")
        parts.append("体感 \(weather.apparentTemperature)°C")
        parts.append("最高 \(weather.high)° / 最低 \(weather.low)°")
        parts.append("湿度 \(weather.humidity)%")
        if weather.windSpeed > 0 {
            parts.append("风速 \(weather.windSpeed) km/h")
        }
        if let uv = weather.uvIndex {
            parts.append("UV \(uv)")
        }
        if let rain = weather.precipitationChance {
            parts.append("降水 \(rain)%")
        }
        return parts.joined(separator: "，")
    }

    private static func composePromptText(
        userPrompt: String,
        weatherSummary: String,
        candidatesBySlot: [String: [WardrobeItem]]
    ) -> String {
        var lines: [String] = []
        lines.append("用户想要：\(userPrompt.isEmpty ? "今日合适的搭配" : userPrompt)")
        lines.append("当前天气：\(weatherSummary)")
        lines.append("")
        lines.append("可选单品（按槽位分组，每行一件，格式：[id] 名字·颜色·季节·标签）：")

        for slotKey in AIWardrobeContext.slotKeys {
            let items = candidatesBySlot[slotKey] ?? []
            if items.isEmpty { continue }
            lines.append("# \(slotDisplayTitle(for: slotKey))")
            for item in items {
                lines.append(formatItemLine(item))
            }
        }

        lines.append("")
        lines.append("规则：")
        lines.append("1. 只能从上方列表里挑选 ID，不要发明新单品。")
        lines.append("2. 上装、下装尽量都填；连衣裙类放上装，下装可省。")
        lines.append("3. 外套依据气温和场景决定，温暖室内可不填。")
        lines.append("4. 鞋、包、配饰按场景需要填；不需要可以省。")
        lines.append("5. reason 用 30-60 个汉字解释为什么这样搭配。")

        return lines.joined(separator: "\n")
    }

    private static func slotDisplayTitle(for slotKey: String) -> String {
        switch slotKey {
        case "top": return "上装 top"
        case "bottom": return "下装 bottom"
        case "outerwear": return "外套 outerwear"
        case "shoes": return "鞋 shoes"
        case "bag": return "包 bag"
        case "accessory": return "配饰 accessory"
        default: return slotKey
        }
    }

    private static func formatItemLine(_ item: WardrobeItem) -> String {
        let tags = item.styleTags.prefix(3).joined(separator: "/")
        let tagSuffix = tags.isEmpty ? "" : "·" + tags
        let favoriteMark = item.isFavorite ? " ★" : ""
        return "[\(item.id.uuidString.lowercased())] \(item.name)·\(item.colorName)·\(item.season)\(tagSuffix)\(favoriteMark)"
    }
}
