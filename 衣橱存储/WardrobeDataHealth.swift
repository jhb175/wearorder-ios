import Foundation

struct WardrobeDataHealthSnapshot {
    let generatedAt: Date
    let itemCount: Int
    let outfitCount: Int
    let planCount: Int
    let photoCount: Int
    let totalPhotoBytes: Int
    let issues: [WardrobeDataHealthIssue]

    var statusTitle: String {
        if issues.contains(where: { $0.severity == .critical }) {
            return "需要处理"
        }
        if issues.contains(where: { $0.severity == .warning }) {
            return "有待整理"
        }
        return "状态良好"
    }

    var statusSubtitle: String {
        if issues.isEmpty {
            return "当前衣橱、搭配和计划数据没有发现明显问题。"
        }
        return "发现 \(issues.count) 个可优化项，建议定期处理。"
    }

    var totalPhotoStorageText: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalPhotoBytes), countStyle: .file)
    }

    static func make(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan],
        now: Date = .now
    ) -> WardrobeDataHealthSnapshot {
        var issues: [WardrobeDataHealthIssue] = []

        if items.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "empty-wardrobe",
                    severity: .warning,
                    title: "衣橱还是空的",
                    message: "推荐、OOTD 和计划都依赖衣物数据，建议先添加常穿上装、下装和鞋履。",
                    actionHint: AppReleaseInfo.allowsSampleDataEntry ? "添加衣物或载入示例数据" : "添加衣物"
                )
            )
        }

        let categories = Set(items.map(\.category))
        let missingCoreCategories: [String] = [
            ("上装", ["上装"]),
            ("下装", ["下装", "裙装"]),
            ("鞋履", ["鞋履"])
        ].compactMap { title, aliases -> String? in
            aliases.contains(where: categories.contains) ? nil : title
        }

        if !items.isEmpty, !missingCoreCategories.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "missing-core-categories",
                    severity: .warning,
                    title: "核心分类不完整",
                    message: "缺少 \(missingCoreCategories.joined(separator: "、"))，穿搭推荐可能无法形成完整闭环。",
                    actionHint: "补录缺失分类"
                )
            )
        }

        let duplicateNameGroups = Dictionary(grouping: items) { item in
            item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        .filter { !$0.key.isEmpty && $0.value.count > 1 }

        if !duplicateNameGroups.isEmpty {
            let duplicateNames = duplicateNameGroups.values
                .compactMap(\.first?.name)
                .sorted()
                .prefix(3)
                .joined(separator: "、")
            issues.append(
                WardrobeDataHealthIssue(
                    id: "duplicate-item-names",
                    severity: .info,
                    title: "存在重复衣物名称",
                    message: "检测到 \(duplicateNameGroups.count) 组重名衣物：\(duplicateNames)。",
                    actionHint: "用品牌、颜色或场景区分名称"
                )
            )
        }

        let largePhotoItems = items.filter { ($0.imageData?.count ?? 0) > 1_500_000 }
        if !largePhotoItems.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "large-photos",
                    severity: .info,
                    title: "部分照片体积偏大",
                    message: "\(largePhotoItems.count) 件衣物照片超过 1.5 MB，长期使用可能增加备份和加载成本。",
                    actionHint: "重新选择或压缩照片"
                )
            )
        }

        let missingMetadataItems = items.filter { $0.trimmedBrand == nil || $0.trimmedSize == nil }
        if !items.isEmpty, !missingMetadataItems.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "missing-item-metadata",
                    severity: .info,
                    title: "衣物资料还可补全",
                    message: "\(missingMetadataItems.count) 件衣物缺少品牌或尺码，后续统计和筛选会不够细。",
                    actionHint: "补充品牌和尺码"
                )
            )
        }

        let incompleteOutfits = outfits.filter(\.isIncomplete)
        if !incompleteOutfits.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "incomplete-outfits",
                    severity: .warning,
                    title: "有未完整的 OOTD",
                    message: "\(incompleteOutfits.count) 套 OOTD 缺少上装或下装，首页和计划展示可能不够准确。",
                    actionHint: "进入 OOTD 详情补齐单品"
                )
            )
        }

        let todayOutfits = outfits.filter(\.isToday)
        if todayOutfits.count > 1 {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "multiple-today-outfits",
                    severity: .critical,
                    title: "今日搭配不唯一",
                    message: "当前有 \(todayOutfits.count) 套 OOTD 标记为今日搭配，首页可能读取到非预期组合。",
                    actionHint: "只保留一套今日搭配"
                )
            )
        }

        let invalidReminderPlans = plans.filter { plan in
            guard plan.reminderEnabled else { return false }
            guard let reminderDate = plan.reminderDate else { return true }
            return reminderDate <= now
        }

        if !invalidReminderPlans.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "invalid-reminders",
                    severity: .warning,
                    title: "存在失效提醒",
                    message: "\(invalidReminderPlans.count) 条计划开启了提醒，但提醒时间为空或已过去。",
                    actionHint: "重新选择未来提醒时间"
                )
            )
        }

        let emptyPlanOutfits = plans.filter { plan in
            plan.linkedOutfit == nil &&
            plan.outfitSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if !emptyPlanOutfits.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "plans-without-outfit",
                    severity: .info,
                    title: "部分计划没有搭配信息",
                    message: "\(emptyPlanOutfits.count) 条计划没有关联 OOTD，也没有手写搭配摘要。",
                    actionHint: "给计划绑定 OOTD"
                )
            )
        }

        let sameDayPlanGroups = Dictionary(grouping: plans) {
            Calendar.current.startOfDay(for: $0.date)
        }
        .filter { $0.value.count > 1 }

        if !sameDayPlanGroups.isEmpty {
            issues.append(
                WardrobeDataHealthIssue(
                    id: "same-day-plan-density",
                    severity: .info,
                    title: "同日计划较密集",
                    message: "\(sameDayPlanGroups.count) 天安排了多条穿搭计划，出门前建议确认最终选择。",
                    actionHint: "用计划冲突筛选器检查"
                )
            )
        }

        let photoBytes = items.reduce(0) { partialResult, item in
            partialResult + (item.imageData?.count ?? 0)
        }

        return WardrobeDataHealthSnapshot(
            generatedAt: now,
            itemCount: items.count,
            outfitCount: outfits.count,
            planCount: plans.count,
            photoCount: items.filter { $0.imageData != nil }.count,
            totalPhotoBytes: photoBytes,
            issues: issues.sorted()
        )
    }
}

struct WardrobeDataHealthIssue: Identifiable, Hashable, Comparable {
    let id: String
    let severity: WardrobeDataHealthSeverity
    let title: String
    let message: String
    let actionHint: String

    static func < (lhs: WardrobeDataHealthIssue, rhs: WardrobeDataHealthIssue) -> Bool {
        if lhs.severity == rhs.severity {
            return lhs.title < rhs.title
        }
        return lhs.severity > rhs.severity
    }
}

enum WardrobeDataHealthSeverity: Int, Comparable {
    case info = 0
    case warning = 1
    case critical = 2

    static func < (lhs: WardrobeDataHealthSeverity, rhs: WardrobeDataHealthSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
