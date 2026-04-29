import Foundation

struct WardrobeBatchDeletionSummary: Equatable {
    let itemCount: Int
    let affectedOutfitCount: Int
    let affectedPlanCount: Int
    let photoItemCount: Int

    var hasSelection: Bool {
        itemCount > 0
    }

    var alertTitle: String {
        "删除选中的 \(itemCount) 件衣物？"
    }

    var alertMessage: String {
        var lines = [
            "衣物会从本地衣橱删除。"
        ]

        if photoItemCount > 0 {
            lines.append("会一并移除 \(photoItemCount) 件衣物的本地图片文件。")
        }
        if affectedOutfitCount > 0 {
            lines.append("\(affectedOutfitCount) 套 OOTD 会自动清空对应单品位置。")
        }
        if affectedPlanCount > 0 {
            lines.append("\(affectedPlanCount) 条计划会保留，并继续显示对应 OOTD 的剩余单品。")
        }
        if affectedOutfitCount == 0 && affectedPlanCount == 0 {
            lines.append("当前没有 OOTD 或计划引用这些衣物。")
        }

        return lines.joined(separator: "\n")
    }

    static func make(
        itemsToDelete: [WardrobeItem],
        outfits: [OOTDOutfit],
        plans: [OutfitPlan]
    ) -> WardrobeBatchDeletionSummary {
        let selectedItemIDs = Set(itemsToDelete.map(\.id))
        let affectedOutfits = outfits.filter { outfit in
            !selectedItemIDs.isDisjoint(with: outfit.orderedItems.map(\.id))
        }
        let affectedOutfitIDs = Set(affectedOutfits.map(\.id))
        let affectedPlanCount = plans.filter { plan in
            guard let linkedOutfitID = plan.linkedOutfit?.id else { return false }
            return affectedOutfitIDs.contains(linkedOutfitID)
        }.count

        return WardrobeBatchDeletionSummary(
            itemCount: itemsToDelete.count,
            affectedOutfitCount: affectedOutfits.count,
            affectedPlanCount: affectedPlanCount,
            photoItemCount: itemsToDelete.filter(\.hasPhoto).count
        )
    }
}
