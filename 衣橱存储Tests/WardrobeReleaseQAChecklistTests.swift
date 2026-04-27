import XCTest
@testable import 衣橱存储

final class WardrobeReleaseQAChecklistTests: XCTestCase {
    func testChecklistCoversEightCommercialFlowsInOrder() {
        XCTAssertEqual(WardrobeReleaseQAChecklist.expectedFlowCount, 8)
        XCTAssertEqual(WardrobeReleaseQAChecklist.orderedFlows.count, 8)
        XCTAssertEqual(WardrobeReleaseQAChecklist.orderedFlows.map(\.order), Array(1...8))
        XCTAssertEqual(
            WardrobeReleaseQAChecklist.orderedFlows.map(\.title),
            [
                "首次启动",
                "空衣橱引导",
                "天气预报",
                "添加与编辑衣物",
                "创建 OOTD",
                "创建计划与提醒",
                "备份恢复",
                "隐私与支持"
            ]
        )
    }

    func testEveryFlowHasReleaseBlockingAcceptanceCriteria() {
        for flow in WardrobeReleaseQAChecklist.orderedFlows {
            XCTAssertTrue(flow.isReleaseBlocking)
            XCTAssertFalse(flow.entryPoint.isEmpty)
            XCTAssertGreaterThanOrEqual(flow.acceptanceCriteria.count, 3)
            XCTAssertFalse(flow.acceptanceCriteria.contains { $0.contains("TODO") })
            XCTAssertFalse(flow.acceptanceCriteria.contains { $0.contains("下一阶段") })
            XCTAssertFalse(flow.acceptanceCriteria.contains { $0.contains("占位") })
        }
    }

    func testPhysicalDeviceCoverageIncludesSystemPermissionFlows() {
        XCTAssertEqual(
            Set(WardrobeReleaseQAChecklist.physicalDeviceFlows),
            [.weatherForecast, .addClothing, .createPlanReminder, .backupRestore]
        )
    }

    func testPreflightCommandsIncludeStrictAppStoreAudit() {
        XCTAssertTrue(WardrobeReleaseQAChecklist.requiredPreflightCommands.contains("xcodebuild test"))
        XCTAssertTrue(WardrobeReleaseQAChecklist.requiredPreflightCommands.contains("./scripts/run_local_smoke_test.sh"))
        XCTAssertTrue(WardrobeReleaseQAChecklist.requiredPreflightCommands.contains("./scripts/audit_app_store_readiness.sh --strict"))
    }
}
