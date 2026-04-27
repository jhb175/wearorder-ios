import Foundation

struct WardrobeInsightsSnapshot: Equatable {
    let itemCount: Int
    let pricedItemCount: Int
    let totalPurchaseValue: Double
    let completeDetailCount: Int
    let categoryRows: [WardrobeInsightRank]
    let seasonRows: [WardrobeInsightRank]
    let colorRows: [WardrobeInsightRank]
    let brandRows: [WardrobeInsightRank]
    let sizeRows: [WardrobeInsightRank]
    let purchaseChannelRows: [WardrobeInsightRank]

    var averagePurchaseValue: Double? {
        guard pricedItemCount > 0 else { return nil }
        return totalPurchaseValue / Double(pricedItemCount)
    }

    var totalPurchaseValueText: String {
        currencyText(totalPurchaseValue)
    }

    var averagePurchaseValueText: String {
        averagePurchaseValue.map(currencyText) ?? "暂无"
    }

    var pricedCoverageText: String {
        "\(pricedItemCount)/\(itemCount)"
    }

    var detailCompletionText: String {
        "\(completeDetailCount)/\(itemCount)"
    }

    var topBrandText: String {
        brandRows.first?.title ?? "暂无"
    }

    var topColorText: String {
        colorRows.first?.title ?? "暂无"
    }

    var topSeasonText: String {
        seasonRows.first?.title ?? "暂无"
    }

    static func make(items: [WardrobeItem]) -> WardrobeInsightsSnapshot {
        let pricedItems = items.compactMap(\.purchasePrice).filter { $0 >= 0 }

        return WardrobeInsightsSnapshot(
            itemCount: items.count,
            pricedItemCount: pricedItems.count,
            totalPurchaseValue: pricedItems.reduce(0, +),
            completeDetailCount: items.filter { !$0.needsDetailCompletion }.count,
            categoryRows: rankedRows(from: items.map(\.category), total: items.count),
            seasonRows: rankedRows(from: items.map(\.season), total: items.count),
            colorRows: rankedRows(from: items.map(\.colorName), total: items.count),
            brandRows: rankedRows(from: items.compactMap(\.trimmedBrand), total: items.count),
            sizeRows: rankedRows(from: items.compactMap(\.trimmedSize), total: items.count),
            purchaseChannelRows: rankedRows(from: items.compactMap(\.trimmedPurchaseChannel), total: items.count)
        )
    }

    private static func rankedRows(from values: [String], total: Int) -> [WardrobeInsightRank] {
        Dictionary(grouping: values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { $0 }
            .map { title, values in
                WardrobeInsightRank(title: title, count: values.count, total: total)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
    }

    private func currencyText(_ value: Double) -> String {
        value.formatted(.currency(code: "CNY"))
    }
}

struct WardrobeInsightRank: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let count: Int
    let total: Int

    var share: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var shareText: String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }
}
