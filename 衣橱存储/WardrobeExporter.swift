import Foundation

enum WardrobeExporter {
    static func plainText(from items: [WardrobeItem]) -> String {
        let sortedItems = items.sorted {
            if $0.category == $1.category {
                return $0.name < $1.name
            }
            return $0.category < $1.category
        }

        var lines: [String] = [
            "衣橱清单",
            "导出时间：\(Date.now.formatted(.dateTime.year().month().day().hour().minute()))",
            "单品数量：\(sortedItems.count)",
            ""
        ]

        lines.append(contentsOf: insightsSection(items: sortedItems))
        lines.append("")

        for item in sortedItems {
            lines.append("- \(item.name)")
            lines.append("  分类：\(item.category)")
            lines.append("  颜色：\(item.colorName)")
            lines.append("  季节：\(item.season)")
            appendPurchaseLines(for: item, to: &lines, prefix: "  ")
            if item.isFavorite {
                lines.append("  收藏：是")
            }
            if !item.styleTags.isEmpty {
                lines.append("  标签：\(item.styleTags.joined(separator: "、"))")
            }
            if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("  备注：\(item.notes)")
            }
            if let careNotes = item.trimmedCareNotes {
                lines.append("  保养：\(careNotes)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    static func fullReport(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan]
    ) -> String {
        var lines: [String] = [
            "\(AppReleaseInfo.appName)完整报告",
            "导出时间：\(formattedDateTime(.now))",
            "单品数量：\(items.count)",
            "OOTD 数量：\(outfits.count)",
            "计划数量：\(plans.count)",
            ""
        ]

        lines.append(contentsOf: wardrobeSection(items: items))
        lines.append("")
        lines.append(contentsOf: ootdSection(outfits: outfits))
        lines.append("")
        lines.append(contentsOf: plannerSection(plans: plans))

        return lines.joined(separator: "\n")
    }

    static func plansReport(from plans: [OutfitPlan]) -> String {
        var lines: [String] = [
            "穿搭计划清单",
            "导出时间：\(formattedDateTime(.now))",
            "计划数量：\(plans.count)",
            ""
        ]

        lines.append(contentsOf: plannerSection(plans: plans))
        return lines.joined(separator: "\n")
    }

    static func outfitReport(
        for outfit: OOTDOutfit,
        linkedPlans: [OutfitPlan]
    ) -> String {
        var lines: [String] = [
            "OOTD 搭配详情",
            "导出时间：\(formattedDateTime(.now))",
            "",
            "搭配名称：\(outfit.title)",
            "创建时间：\(formattedDateTime(outfit.createdAt))",
            "今日搭配：\(outfit.isToday ? "是" : "否")",
            "单品数量：\(outfit.orderedItems.count)",
            ""
        ]

        lines.append("一、搭配单品")
        for slot in outfitSlots(for: outfit) {
            lines.append("- \(slot.title)：\(slot.item?.name ?? "未选择")")
            if let item = slot.item {
                lines.append("  \(item.category) · \(item.colorName) · \(item.season)")
            }
        }

        if !trimmed(outfit.notes).isEmpty {
            lines.append("")
            lines.append("二、备注")
            lines.append(trimmed(outfit.notes))
        }

        lines.append("")
        lines.append("三、关联计划")
        if linkedPlans.isEmpty {
            lines.append("暂无计划引用这套搭配。")
        } else {
            for plan in linkedPlans.sorted(by: { $0.date < $1.date }) {
                lines.append("- \(formattedDate(plan.date)) · \(plan.title)")
                lines.append("  场景：\(plan.occasion)")
                lines.append("  提醒：\(reminderText(for: plan))")
            }
        }

        if outfit.isIncomplete {
            lines.append("")
            lines.append("缺失位置：\(outfit.missingSlotTitles.joined(separator: "、"))")
        }

        return lines.joined(separator: "\n")
    }

    static func itemReport(
        for item: WardrobeItem,
        linkedOutfits: [OOTDOutfit],
        linkedPlans: [OutfitPlan]
    ) -> String {
        var lines: [String] = [
            "衣物详情",
            "导出时间：\(formattedDateTime(.now))",
            "",
            "名称：\(item.name)",
            "分类：\(item.category)",
            "颜色：\(item.colorName)",
            "季节：\(item.season)",
            "收藏：\(item.isFavorite ? "是" : "否")",
            "图片：\(item.imageData == nil ? "默认图标" : "已添加照片")",
            "创建：\(formattedDateTime(item.createdAt))",
            "更新：\(formattedDateTime(item.lastModifiedAt))",
            ""
        ]

        appendPurchaseLines(for: item, to: &lines)
        if !item.styleTags.isEmpty {
            lines.append("风格标签：\(item.styleTags.joined(separator: "、"))")
        }
        if !trimmed(item.notes).isEmpty {
            lines.append("备注：\(trimmed(item.notes))")
        }
        if let careNotes = item.trimmedCareNotes {
            lines.append("保养备注：\(careNotes)")
        }

        lines.append("")
        lines.append("一、关联 OOTD")
        if linkedOutfits.isEmpty {
            lines.append("暂无 OOTD 使用这件衣物。")
        } else {
            for outfit in linkedOutfits.sorted(by: { $0.createdAt > $1.createdAt }) {
                lines.append("- \(outfit.title)\(outfit.isToday ? "（今日搭配）" : "")")
                lines.append("  单品：\(outfit.summaryText)")
            }
        }

        lines.append("")
        lines.append("二、关联计划")
        if linkedPlans.isEmpty {
            lines.append("暂无计划通过 OOTD 使用这件衣物。")
        } else {
            for plan in linkedPlans.sorted(by: { $0.date < $1.date }) {
                lines.append("- \(formattedDate(plan.date)) · \(plan.title)")
                lines.append("  场景：\(plan.occasion)")
                lines.append("  搭配：\(plan.linkedOutfit?.title ?? plan.outfitSummary)")
                lines.append("  提醒：\(reminderText(for: plan))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func wardrobeSection(items: [WardrobeItem]) -> [String] {
        let sortedItems = items.sorted {
            if $0.category == $1.category {
                return $0.name < $1.name
            }
            return $0.category < $1.category
        }

        var lines = ["一、衣橱单品"]
        guard !sortedItems.isEmpty else {
            lines.append("暂无衣物。")
            return lines
        }

        for item in sortedItems {
            lines.append("- \(item.name)")
            lines.append("  分类：\(item.category)")
            lines.append("  颜色：\(item.colorName)")
            lines.append("  季节：\(item.season)")
            appendPurchaseLines(for: item, to: &lines, prefix: "  ")
            lines.append("  收藏：\(item.isFavorite ? "是" : "否")")
            if !item.styleTags.isEmpty {
                lines.append("  标签：\(item.styleTags.joined(separator: "、"))")
            }
            if !trimmed(item.notes).isEmpty {
                lines.append("  备注：\(trimmed(item.notes))")
            }
            if let careNotes = item.trimmedCareNotes {
                lines.append("  保养：\(careNotes)")
            }
        }

        return lines
    }

    private static func insightsSection(items: [WardrobeItem]) -> [String] {
        let snapshot = WardrobeInsightsSnapshot.make(items: items)
        var lines = [
            "衣橱报告",
            "已记录金额：\(snapshot.totalPurchaseValueText)",
            "平均价格：\(snapshot.averagePurchaseValueText)",
            "填写价格：\(snapshot.pricedCoverageText)",
            "资料完整度：\(snapshot.detailCompletionText)",
            "常见颜色：\(snapshot.topColorText)",
            "常见季节：\(snapshot.topSeasonText)",
            "常见品牌：\(snapshot.topBrandText)"
        ]

        appendRanks(title: "品牌分布", rows: snapshot.brandRows, to: &lines)
        appendRanks(title: "购买渠道", rows: snapshot.purchaseChannelRows, to: &lines)
        return lines
    }

    private static func ootdSection(outfits: [OOTDOutfit]) -> [String] {
        let sortedOutfits = outfits.sorted { $0.createdAt > $1.createdAt }

        var lines = ["二、OOTD 搭配"]
        guard !sortedOutfits.isEmpty else {
            lines.append("暂无 OOTD。")
            return lines
        }

        for outfit in sortedOutfits {
            lines.append("- \(outfit.title)\(outfit.isToday ? "（今日搭配）" : "")")
            lines.append("  创建：\(formattedDate(outfit.createdAt))")
            lines.append("  单品：\(outfit.summaryText)")
            if !trimmed(outfit.notes).isEmpty {
                lines.append("  备注：\(trimmed(outfit.notes))")
            }
            if outfit.isIncomplete {
                lines.append("  缺失：\(outfit.missingSlotTitles.joined(separator: "、"))")
            }
        }

        return lines
    }

    private static func plannerSection(plans: [OutfitPlan]) -> [String] {
        let sortedPlans = plans.sorted { $0.date < $1.date }

        var lines = ["三、穿搭计划"]
        guard !sortedPlans.isEmpty else {
            lines.append("暂无计划。")
            return lines
        }

        for plan in sortedPlans {
            lines.append("- \(plan.title)")
            lines.append("  日期：\(formattedDate(plan.date))")
            lines.append("  场景：\(plan.occasion)")
            lines.append("  搭配：\(plan.linkedOutfit?.title ?? plan.outfitSummary)")
            lines.append("  提醒：\(reminderText(for: plan))")
            if !trimmed(plan.notes).isEmpty {
                lines.append("  备注：\(trimmed(plan.notes))")
            }
        }

        return lines
    }

    private static func reminderText(for plan: OutfitPlan) -> String {
        guard plan.reminderEnabled else { return "未开启" }
        guard let reminderDate = plan.reminderDate else { return "已开启，未设置时间" }
        return formattedDateTime(reminderDate)
    }

    private static func outfitSlots(for outfit: OOTDOutfit) -> [(title: String, item: WardrobeItem?)] {
        [
            ("上装", outfit.topItem),
            ("下装", outfit.bottomItem),
            ("外套", outfit.outerwearItem),
            ("鞋子", outfit.shoesItem),
            ("包", outfit.bagItem),
            ("配饰", outfit.accessoryItem)
        ]
    }

    private static func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
    }

    private static func formattedDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute())
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func appendPurchaseLines(for item: WardrobeItem, to lines: inout [String], prefix: String = "") {
        for line in item.purchaseDetailLines {
            lines.append("\(prefix)\(line)")
        }
    }

    private static func appendRanks(title: String, rows: [WardrobeInsightRank], to lines: inout [String]) {
        guard !rows.isEmpty else { return }
        lines.append("\(title)：")
        for row in rows.prefix(5) {
            lines.append("  \(row.title)：\(row.count) 件（\(row.shareText)）")
        }
    }
}
