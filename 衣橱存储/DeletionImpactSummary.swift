import SwiftUI

struct DeletionImpactSummary: Equatable {
    let headline: String
    let message: String
    let impactLines: [String]

    var alertMessage: String {
        ([message] + impactLines).joined(separator: "\n")
    }

    static func wardrobeItem(
        itemName: String,
        linkedOutfitCount: Int,
        linkedPlanCount: Int
    ) -> DeletionImpactSummary {
        let associationMessage: String
        if linkedOutfitCount == 0 {
            associationMessage = "“\(itemName)”目前没有被搭配引用。"
        } else if linkedPlanCount == 0 {
            associationMessage = "“\(itemName)”已被 \(linkedOutfitCount) 套搭配使用。"
        } else {
            associationMessage = "“\(itemName)”已被 \(linkedOutfitCount) 套搭配使用，其中 \(linkedPlanCount) 条计划正在引用这些搭配。"
        }

        var impactLines = [
            "衣物会从本地衣橱删除。"
        ]
        if linkedOutfitCount > 0 {
            impactLines.append("相关 OOTD 会自动清空这件单品的位置。")
        }
        if linkedPlanCount > 0 {
            impactLines.append("计划本身会保留，继续显示对应 OOTD 的剩余单品。")
        }

        return DeletionImpactSummary(
            headline: "删除影响",
            message: associationMessage,
            impactLines: impactLines
        )
    }

    static func outfit(
        outfitTitle: String,
        linkedPlanCount: Int,
        isToday: Bool
    ) -> DeletionImpactSummary {
        var impactLines = [
            "衣橱里的单品不会被删除。"
        ]
        if linkedPlanCount > 0 {
            impactLines.append("\(linkedPlanCount) 条计划会保留文字摘要，并解除这套 OOTD 的绑定。")
        }
        if isToday {
            impactLines.append("首页今日搭配会在删除后变为空状态。")
        }

        return DeletionImpactSummary(
            headline: "删除影响",
            message: "将删除 OOTD “\(outfitTitle)”。",
            impactLines: impactLines
        )
    }

    static func plan(
        planTitle: String,
        reminderEnabled: Bool,
        hasLinkedOutfit: Bool
    ) -> DeletionImpactSummary {
        var impactLines = [
            "已保存的 OOTD 和衣物不会被删除。"
        ]
        if reminderEnabled {
            impactLines.append("这条计划的本地提醒会一并移除。")
        }
        if hasLinkedOutfit {
            impactLines.append("只会解除当前计划和 OOTD 的关联。")
        }

        return DeletionImpactSummary(
            headline: "删除影响",
            message: "将删除计划“\(planTitle)”。",
            impactLines: impactLines
        )
    }
}

struct DeletionImpactCard: View {
    let summary: DeletionImpactSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(summary.headline, systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(summary.message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.impactLines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
    }
}
