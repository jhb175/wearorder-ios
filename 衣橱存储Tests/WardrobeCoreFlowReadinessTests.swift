import XCTest
@testable import 衣橱存储

@MainActor
final class WardrobeCoreFlowReadinessTests: XCTestCase {
    func testEmptyWardrobeBlocksOOTDAndPlanCreation() {
        let readiness = WardrobeCoreFlowReadiness.make(items: [], outfits: [])

        XCTAssertFalse(readiness.canCreateOOTD)
        XCTAssertFalse(readiness.canGenerateRecommendation)
        XCTAssertFalse(readiness.canCreatePlan)
        XCTAssertEqual(readiness.missingOOTDRequirementText, "至少需要 1 件上装和 1 件下装/裙装，或 1 件连衣裙/套装。")
        XCTAssertEqual(readiness.ootdBlockedTitle, "先添加衣物")
        XCTAssertEqual(readiness.recommendationBlockedTitle, "先添加衣物")
    }

    func testTopOnlyWardrobeExplainsMissingBottom() {
        let readiness = WardrobeCoreFlowReadiness.make(
            items: [makeItem(name: "白衬衫", category: "上装")],
            outfits: []
        )

        XCTAssertFalse(readiness.canCreateOOTD)
        XCTAssertFalse(readiness.canGenerateRecommendation)
        XCTAssertTrue(readiness.ootdBlockedMessage.contains("下装、裙装"))
        XCTAssertTrue(readiness.recommendationBlockedMessage.contains("下装、裙装"))
    }

    func testOnePieceCanCreateOOTDButDoesNotUnlockRecommendationAlone() {
        let dress = makeItem(name: "白色连衣裙", category: "连衣裙")
        let readiness = WardrobeCoreFlowReadiness.make(items: [dress], outfits: [])

        XCTAssertTrue(readiness.canCreateOOTD)
        XCTAssertFalse(readiness.canGenerateRecommendation)
        XCTAssertTrue(readiness.missingOOTDRequirementText.contains("一件式 OOTD"))
        XCTAssertTrue(readiness.recommendationBlockedMessage.contains("智能推荐还需要"))
    }

    func testTopAndSkirtCanCreateOOTDButPlanRequiresSavedOutfit() {
        let top = makeItem(name: "针织衫", category: "上装")
        let skirt = makeItem(name: "半裙", category: "裙装")
        let readiness = WardrobeCoreFlowReadiness.make(items: [top, skirt], outfits: [])

        XCTAssertTrue(readiness.canCreateOOTD)
        XCTAssertTrue(readiness.canGenerateRecommendation)
        XCTAssertFalse(readiness.canCreatePlan)
        XCTAssertEqual(readiness.planBlockedTitle, "先保存一套 OOTD")
        XCTAssertEqual(readiness.recommendationReadyMessage, "已具备推荐基础：1 件上装、1 件下装/裙装。")
    }

    func testSavedOutfitUnlocksPlanCreation() {
        let top = makeItem(name: "针织衫", category: "上装")
        let bottom = makeItem(name: "牛仔裤", category: "下装")
        let outfit = OOTDOutfit(title: "周末搭配", notes: "", topItem: top, bottomItem: bottom)
        let readiness = WardrobeCoreFlowReadiness.make(items: [top, bottom], outfits: [outfit])

        XCTAssertTrue(readiness.canCreateOOTD)
        XCTAssertTrue(readiness.canCreatePlan)
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
