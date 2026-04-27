import Foundation

struct ClosetOrganizationSnapshot: Equatable {
    let itemCount: Int
    let categoryRows: [ClosetCategoryCoverage]
    let missingCoreCategories: [String]
    let unusedItemCount: Int
    let missingImageCount: Int
    let detailGapCount: Int
    let favoriteCount: Int

    var coveredCategoryCount: Int {
        categoryRows.filter { $0.count > 0 }.count
    }

    var coverageText: String {
        "\(coveredCategoryCount)/\(categoryRows.count)"
    }

    var maxCategoryCount: Int {
        max(categoryRows.map(\.count).max() ?? 0, 1)
    }

    var tasks: [ClosetOrganizationTask] {
        if itemCount == 0 {
            return [
                ClosetOrganizationTask(
                    id: "add-first-item",
                    title: "添加第一件衣物",
                    message: "衣橱为空时，推荐、OOTD 和计划都还无法形成闭环。",
                    systemImage: "plus.viewfinder",
                    kind: .addClothing
                )
            ]
        }

        var tasks: [ClosetOrganizationTask] = []
        if !missingCoreCategories.isEmpty {
            tasks.append(
                ClosetOrganizationTask(
                    id: "missing-core-categories",
                    title: "补齐核心分类",
                    message: "缺少 \(missingCoreCategories.joined(separator: "、"))，会影响 OOTD 和推荐完整度。",
                    systemImage: "square.grid.2x2",
                    kind: .addClothing
                )
            )
        }
        if detailGapCount > 0 {
            tasks.append(
                ClosetOrganizationTask(
                    id: "detail-gaps",
                    title: "补全衣物资料",
                    message: "\(detailGapCount) 件衣物缺少图片、风格标签、品牌或尺码。",
                    systemImage: "checklist",
                    kind: .showNeedsDetails
                )
            )
        }
        if unusedItemCount > 0 {
            tasks.append(
                ClosetOrganizationTask(
                    id: "unused-items",
                    title: "把单品加入搭配",
                    message: "\(unusedItemCount) 件衣物还没有出现在任何 OOTD 中。",
                    systemImage: "link.badge.plus",
                    kind: .showUnused
                )
            )
        }

        return tasks
    }

    static func make(
        items: [WardrobeItem],
        outfits: [OOTDOutfit]
    ) -> ClosetOrganizationSnapshot {
        let categories = WardrobeCategory.allCases.map(\.rawValue)
        let itemCountByCategory = Dictionary(grouping: items, by: \.category)
            .mapValues(\.count)
        let categoryRows = categories.map { category in
            ClosetCategoryCoverage(
                category: category,
                count: itemCountByCategory[category, default: 0],
                isCore: isCoreCategory(category)
            )
        }

        let itemIDsInOutfits = Set(outfits.flatMap { $0.orderedItems.map(\.id) })
        let missingCoreCategories = [
            ("上装", [WardrobeCategory.top.rawValue]),
            ("下装/裙装", [WardrobeCategory.bottom.rawValue, WardrobeCategory.skirt.rawValue]),
            ("鞋履", [WardrobeCategory.shoes.rawValue])
        ].compactMap { title, aliases -> String? in
            aliases.contains { itemCountByCategory[$0, default: 0] > 0 } ? nil : title
        }

        return ClosetOrganizationSnapshot(
            itemCount: items.count,
            categoryRows: categoryRows,
            missingCoreCategories: missingCoreCategories,
            unusedItemCount: items.filter { !itemIDsInOutfits.contains($0.id) }.count,
            missingImageCount: items.filter { $0.imageData == nil }.count,
            detailGapCount: items.filter(\.needsDetailCompletion).count,
            favoriteCount: items.filter(\.isFavorite).count
        )
    }

    private static func isCoreCategory(_ category: String) -> Bool {
        category == WardrobeCategory.top.rawValue ||
        category == WardrobeCategory.bottom.rawValue ||
        category == WardrobeCategory.skirt.rawValue ||
        category == WardrobeCategory.shoes.rawValue
    }
}

struct ClosetCategoryCoverage: Identifiable, Equatable {
    var id: String { category }
    let category: String
    let count: Int
    let isCore: Bool
}

struct ClosetOrganizationTask: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
    let kind: Kind

    enum Kind: Equatable {
        case addClothing
        case showNeedsDetails
        case showUnused
    }
}
