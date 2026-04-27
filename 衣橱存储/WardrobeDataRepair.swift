import Foundation

struct WardrobeDataRepairSummary: Equatable {
    let normalizedItems: Int
    let normalizedOutfits: Int
    let normalizedPlans: Int
    let disabledInvalidReminders: Int
    let resolvedTodayDuplicates: Int

    var totalChanges: Int {
        normalizedItems + normalizedOutfits + normalizedPlans + disabledInvalidReminders + resolvedTodayDuplicates
    }

    var hasChanges: Bool {
        totalChanges > 0
    }

    var feedbackMessage: String {
        guard hasChanges else {
            return "当前没有发现可自动修复的数据问题。"
        }

        var parts: [String] = []
        if normalizedItems > 0 { parts.append("衣物 \(normalizedItems)") }
        if normalizedOutfits > 0 { parts.append("OOTD \(normalizedOutfits)") }
        if normalizedPlans > 0 { parts.append("计划 \(normalizedPlans)") }
        if disabledInvalidReminders > 0 { parts.append("失效提醒 \(disabledInvalidReminders)") }
        if resolvedTodayDuplicates > 0 { parts.append("今日搭配冲突 \(resolvedTodayDuplicates)") }
        return "已修复：" + parts.joined(separator: "、") + "。"
    }
}

@MainActor
enum WardrobeDataRepair {
    static func preview(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan],
        now: Date = .now
    ) -> WardrobeDataRepairSummary {
        repair(items: items, outfits: outfits, plans: plans, now: now, applyChanges: false)
    }

    @discardableResult
    static func apply(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan],
        now: Date = .now
    ) -> WardrobeDataRepairSummary {
        repair(items: items, outfits: outfits, plans: plans, now: now, applyChanges: true)
    }

    private static func repair(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan],
        now: Date,
        applyChanges: Bool
    ) -> WardrobeDataRepairSummary {
        var normalizedItems = 0
        var normalizedOutfits = 0
        var normalizedPlans = 0
        var disabledInvalidReminders = 0

        for item in items {
            if repair(item: item, applyChanges: applyChanges) {
                normalizedItems += 1
            }
        }

        for outfit in outfits {
            if repair(outfit: outfit, applyChanges: applyChanges) {
                normalizedOutfits += 1
            }
        }

        let resolvedTodayDuplicates = resolveTodayDuplicates(
            outfits: outfits,
            applyChanges: applyChanges
        )

        for plan in plans {
            let result = repair(plan: plan, now: now, applyChanges: applyChanges)
            if result.normalized {
                normalizedPlans += 1
            }
            if result.disabledInvalidReminder {
                disabledInvalidReminders += 1
            }
        }

        return WardrobeDataRepairSummary(
            normalizedItems: normalizedItems,
            normalizedOutfits: normalizedOutfits,
            normalizedPlans: normalizedPlans,
            disabledInvalidReminders: disabledInvalidReminders,
            resolvedTodayDuplicates: resolvedTodayDuplicates
        )
    }

    private static func repair(item: WardrobeItem, applyChanges: Bool) -> Bool {
        let normalizedName = fallback(item.name, defaultValue: "未命名衣物")
        let normalizedCategory = normalizedCategory(item.category)
        let normalizedColorName = fallback(item.colorName, defaultValue: "奶油白")
        let normalizedSeason = normalizedSeason(item.season)
        let normalizedImageSymbol = fallback(item.imageSymbol, defaultValue: normalizedCategory.defaultSymbolName)
        let normalizedStyleTagsText = normalizedTags(item.styleTagsText)
        let normalizedNotes = item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBrand = normalizedOptional(item.brand)
        let normalizedSize = normalizedOptional(item.size)
        let normalizedPurchasePrice = normalizedPurchasePrice(item.purchasePrice)
        let normalizedPurchaseChannel = normalizedOptional(item.purchaseChannel)
        let normalizedCareNotes = normalizedOptional(item.careNotes)

        let changed = item.name != normalizedName ||
        item.category != normalizedCategory ||
        item.colorName != normalizedColorName ||
        item.season != normalizedSeason ||
        item.imageSymbol != normalizedImageSymbol ||
        item.styleTagsText != normalizedStyleTagsText ||
        item.notes != normalizedNotes ||
        item.brand != normalizedBrand ||
        item.size != normalizedSize ||
        item.purchasePrice != normalizedPurchasePrice ||
        item.purchaseChannel != normalizedPurchaseChannel ||
        item.careNotes != normalizedCareNotes ||
        item.updatedAt == nil

        guard changed else { return false }

        if applyChanges {
            item.name = normalizedName
            item.category = normalizedCategory
            item.colorName = normalizedColorName
            item.season = normalizedSeason
            item.imageSymbol = normalizedImageSymbol
            item.styleTagsText = normalizedStyleTagsText
            item.notes = normalizedNotes
            item.brand = normalizedBrand
            item.size = normalizedSize
            item.purchasePrice = normalizedPurchasePrice
            item.purchaseChannel = normalizedPurchaseChannel
            item.careNotes = normalizedCareNotes
            item.updatedAt = .now
        }

        return true
    }

    private static func repair(outfit: OOTDOutfit, applyChanges: Bool) -> Bool {
        let normalizedTitle = fallback(outfit.title, defaultValue: "未命名搭配")
        let normalizedNotes = outfit.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let changed = outfit.title != normalizedTitle ||
        outfit.notes != normalizedNotes ||
        outfit.updatedAt == nil

        guard changed else { return false }

        if applyChanges {
            outfit.title = normalizedTitle
            outfit.notes = normalizedNotes
            outfit.updatedAt = .now
        }

        return true
    }

    private static func repair(
        plan: OutfitPlan,
        now: Date,
        applyChanges: Bool
    ) -> (normalized: Bool, disabledInvalidReminder: Bool) {
        let normalizedTitle = fallback(plan.title, defaultValue: "未命名计划")
        let normalizedOccasion = fallback(plan.occasion, defaultValue: "穿搭安排")
        let normalizedNotes = plan.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSummary: String
        if let linkedOutfit = plan.linkedOutfit,
           plan.outfitSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalizedSummary = linkedOutfit.summaryText
        } else {
            normalizedSummary = fallback(plan.outfitSummary, defaultValue: "未绑定 OOTD")
        }

        let hasInvalidReminder = plan.reminderEnabled && ((plan.reminderDate ?? .distantPast) <= now)
        let shouldClearDisabledReminderDate = !plan.reminderEnabled && plan.reminderDate != nil

        let normalized = plan.title != normalizedTitle ||
        plan.occasion != normalizedOccasion ||
        plan.notes != normalizedNotes ||
        plan.outfitSummary != normalizedSummary ||
        shouldClearDisabledReminderDate ||
        hasInvalidReminder ||
        plan.updatedAt == nil

        guard normalized else {
            return (false, false)
        }

        if applyChanges {
            plan.title = normalizedTitle
            plan.occasion = normalizedOccasion
            plan.notes = normalizedNotes
            plan.outfitSummary = normalizedSummary
            if hasInvalidReminder || shouldClearDisabledReminderDate {
                plan.reminderEnabled = false
                plan.reminderDate = nil
            }
            plan.updatedAt = .now
        }

        return (true, hasInvalidReminder)
    }

    private static func resolveTodayDuplicates(
        outfits: [OOTDOutfit],
        applyChanges: Bool
    ) -> Int {
        let todayOutfits = outfits
            .filter(\.isToday)
            .sorted { lhs, rhs in
                lhs.lastModifiedAt > rhs.lastModifiedAt
            }

        guard todayOutfits.count > 1 else { return 0 }

        let outfitsToClear = todayOutfits.dropFirst()
        if applyChanges {
            for outfit in outfitsToClear {
                outfit.isToday = false
                outfit.updatedAt = .now
            }
        }

        return outfitsToClear.count
    }

    private static func fallback(_ text: String, defaultValue: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    private static func normalizedOptional(_ text: String?) -> String? {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedPurchasePrice(_ price: Double?) -> Double? {
        guard let price, price >= 0 else { return nil }
        return price
    }

    private static func normalizedCategory(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return WardrobeCategory(rawValue: trimmed)?.rawValue ?? WardrobeCategory.accessory.rawValue
    }

    private static func normalizedSeason(_ season: String) -> String {
        let trimmed = season.trimmingCharacters(in: .whitespacesAndNewlines)
        return ClothingSeason(rawValue: trimmed)?.rawValue ?? ClothingSeason.all.rawValue
    }

    private static func normalizedTags(_ text: String) -> String {
        var seen: Set<String> = []
        let tags = text
            .replacingOccurrences(of: "，", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { tag in
                if seen.contains(tag) { return false }
                seen.insert(tag)
                return true
            }

        return tags.joined(separator: ", ")
    }
}
