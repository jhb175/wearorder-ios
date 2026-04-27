import Foundation

struct OOTDLibrarySnapshot: Equatable {
    let outfitCount: Int
    let todayCount: Int
    let plannedCount: Int
    let incompleteCount: Int

    var unplannedCount: Int {
        max(outfitCount - plannedCount, 0)
    }

    var tasks: [OOTDLibraryTask] {
        if outfitCount == 0 {
            return [
                OOTDLibraryTask(
                    id: "create-first-ootd",
                    title: "保存第一套 OOTD",
                    message: "先从通勤、周末或轻社交模板开始。",
                    systemImage: "plus",
                    kind: .createOOTD
                )
            ]
        }

        var tasks: [OOTDLibraryTask] = []
        if todayCount == 0 {
            tasks.append(
                OOTDLibraryTask(
                    id: "set-today-outfit",
                    title: "设置今日搭配",
                    message: "首页会读取被标记为今日的 OOTD。",
                    systemImage: "sun.max",
                    kind: .showAll
                )
            )
        }
        if incompleteCount > 0 {
            tasks.append(
                OOTDLibraryTask(
                    id: "complete-outfits",
                    title: "补齐缺失搭配",
                    message: "\(incompleteCount) 套 OOTD 缺少上装或下装。",
                    systemImage: "exclamationmark.triangle",
                    kind: .showIncomplete
                )
            )
        }
        if unplannedCount > 0 {
            tasks.append(
                OOTDLibraryTask(
                    id: "schedule-unplanned-outfits",
                    title: "安排未排期搭配",
                    message: "\(unplannedCount) 套 OOTD 还没有绑定计划。",
                    systemImage: "calendar.badge.plus",
                    kind: .showUnplanned
                )
            )
        }

        return tasks
    }

    static func make(
        outfits: [OOTDOutfit],
        plans: [OutfitPlan]
    ) -> OOTDLibrarySnapshot {
        let plannedOutfitIDs = Set(plans.compactMap { $0.linkedOutfit?.id })
        return OOTDLibrarySnapshot(
            outfitCount: outfits.count,
            todayCount: outfits.filter(\.isToday).count,
            plannedCount: outfits.filter { plannedOutfitIDs.contains($0.id) }.count,
            incompleteCount: outfits.filter(\.isIncomplete).count
        )
    }
}

struct OOTDLibraryTask: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
    let kind: Kind

    enum Kind: Equatable {
        case createOOTD
        case showAll
        case showIncomplete
        case showUnplanned
    }
}
