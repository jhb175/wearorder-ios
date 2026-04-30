import SwiftData
import XCTest
@testable import 衣橱存储

@MainActor
final class OOTDLibrarySnapshotTests: XCTestCase {
    func testEmptyLibrarySuggestsCreatingFirstOOTD() {
        let snapshot = OOTDLibrarySnapshot.make(outfits: [], plans: [])

        XCTAssertEqual(snapshot.outfitCount, 0)
        XCTAssertEqual(snapshot.tasks.map(\.kind), [.createOOTD])
    }

    func testSnapshotTracksPlannedUnplannedAndIncompleteOutfits() {
        let top = makeItem(name: "白衬衫", category: "上装")
        let bottom = makeItem(name: "长裤", category: "下装")
        let plannedOutfit = OOTDOutfit(title: "通勤", notes: "", isToday: true, topItem: top, bottomItem: bottom)
        let incompleteOutfit = OOTDOutfit(title: "缺下装", notes: "", topItem: top)
        let plan = OutfitPlan(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            title: "周一通勤",
            occasion: "办公室",
            outfitSummary: plannedOutfit.summaryText,
            reminderEnabled: false,
            linkedOutfit: plannedOutfit
        )

        let snapshot = OOTDLibrarySnapshot.make(
            outfits: [plannedOutfit, incompleteOutfit],
            plans: [plan]
        )

        XCTAssertEqual(snapshot.outfitCount, 2)
        XCTAssertEqual(snapshot.todayCount, 1)
        XCTAssertEqual(snapshot.plannedCount, 1)
        XCTAssertEqual(snapshot.unplannedCount, 1)
        XCTAssertEqual(snapshot.incompleteCount, 1)
        XCTAssertTrue(snapshot.tasks.map(\.kind).contains(.showIncomplete))
        XCTAssertTrue(snapshot.tasks.map(\.kind).contains(.showUnplanned))
    }

    func testStarterTemplateBuildsDraft() {
        let draft = OOTDStarterTemplate.commute.draft

        XCTAssertEqual(draft.title, "通勤搭配")
        XCTAssertTrue(draft.notes.contains("办公室"))
        XCTAssertTrue(draft.presetTagsText.contains("通勤"))
        XCTAssertTrue(draft.marksAsToday)
    }

    func testPresetTagNormalizationDeduplicatesKnownAndCustomTags() {
        let text = OOTDPresetTag.normalizedText(from: "commute，通勤, 自定义标签, 自定义标签, very-long-custom-tag-name")

        XCTAssertEqual(OOTDPresetTag.normalizedTags(from: text), ["通勤", "自定义标签", "very-long-cu"])
    }

    func testPlanDraftFromPresetInfersDailyContext() {
        let outfit = OOTDOutfit(title: "周一通勤", notes: "", presetTagsText: "通勤")
        let draft = PlanCreationDraft.arrangingPreset(outfit)

        XCTAssertEqual(draft.planKind, .daily)
        XCTAssertEqual(draft.title, "周一通勤")
        XCTAssertEqual(draft.occasion, "通勤")
        XCTAssertEqual(draft.selectedOutfitID, outfit.persistentModelID)
        XCTAssertTrue(draft.notes.contains("OOTD 预设"))
    }

    func testPlanDraftFromPresetInfersSpecialAndTripContexts() {
        let formalOutfit = OOTDOutfit(title: "婚礼穿搭", notes: "", presetTagsText: "仪式")
        let travelOutfit = OOTDOutfit(title: "东京出行", notes: "", presetTagsText: "旅行")

        XCTAssertEqual(PlanCreationDraft.arrangingPreset(formalOutfit).planKind, .specialEvent)
        XCTAssertEqual(PlanCreationDraft.arrangingPreset(travelOutfit).planKind, .trip)
    }

    private func makeItem(name: String, category: String) -> WardrobeItem {
        WardrobeItem(
            name: name,
            category: category,
            colorName: "奶油白",
            season: "四季",
            imageSymbol: "shirt.fill",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
