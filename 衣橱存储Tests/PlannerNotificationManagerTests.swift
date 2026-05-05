import XCTest
@testable import 衣橱存储

@MainActor
final class PlannerNotificationManagerTests: XCTestCase {

    // MARK: - Identifier

    func testIdentifierUsesPlannerPrefixAndUUIDString() {
        let id = UUID()
        let plan = makePlan(id: id, reminderEnabled: false)

        XCTAssertEqual(PlannerNotificationManager.identifier(for: plan), "planner-\(id.uuidString)")
    }

    func testIdentifierIsStableAcrossCalls() {
        let plan = makePlan(reminderEnabled: false)

        let first = PlannerNotificationManager.identifier(for: plan)
        let second = PlannerNotificationManager.identifier(for: plan)
        XCTAssertEqual(first, second)
    }

    func testIdentifierDiffersBetweenPlans() {
        let planA = makePlan(reminderEnabled: false)
        let planB = makePlan(reminderEnabled: false)

        XCTAssertNotEqual(
            PlannerNotificationManager.identifier(for: planA),
            PlannerNotificationManager.identifier(for: planB)
        )
    }

    // MARK: - scheduleNotification short-circuits

    func testScheduleReturnsDisabledWhenReminderNotEnabled() async {
        let plan = makePlan(reminderEnabled: false, reminderDate: Date.now.addingTimeInterval(3600))

        let result = await PlannerNotificationManager.scheduleNotification(for: plan)

        XCTAssertEqual(result, .disabled)
    }

    func testScheduleReturnsMissingDateWhenReminderEnabledButNoReminderDate() async {
        let plan = makePlan(reminderEnabled: true, reminderDate: nil)

        let result = await PlannerNotificationManager.scheduleNotification(for: plan)

        XCTAssertEqual(result, .missingDate)
    }

    func testScheduleReturnsPastDateWhenReminderInPast() async {
        let plan = makePlan(reminderEnabled: true, reminderDate: Date.now.addingTimeInterval(-3600))

        let result = await PlannerNotificationManager.scheduleNotification(for: plan)

        XCTAssertEqual(result, .pastDate)
    }

    // MARK: - PlannerNotificationResult

    func testIsScheduledIsTrueOnlyForScheduledCase() {
        XCTAssertTrue(PlannerNotificationResult.scheduled.isScheduled)
        XCTAssertFalse(PlannerNotificationResult.disabled.isScheduled)
        XCTAssertFalse(PlannerNotificationResult.missingDate.isScheduled)
        XCTAssertFalse(PlannerNotificationResult.pastDate.isScheduled)
        XCTAssertFalse(PlannerNotificationResult.permissionDenied.isScheduled)
        XCTAssertFalse(PlannerNotificationResult.failed("oops").isScheduled)
    }

    func testFeedbackTitleCoversEveryResultCase() {
        for result in allRepresentativeResults {
            XCTAssertFalse(result.feedbackTitle.isEmpty, "Missing title for \(result)")
        }
    }

    func testFeedbackMessageCoversEveryResultCase() {
        for result in allRepresentativeResults {
            XCTAssertFalse(result.feedbackMessage.isEmpty, "Missing message for \(result)")
        }
    }

    func testFailedFeedbackMessageIncludesUnderlyingReason() {
        let reason = "rate limited"
        let message = PlannerNotificationResult.failed(reason).feedbackMessage

        XCTAssertTrue(message.contains(reason), "expected reason '\(reason)' in '\(message)'")
    }

    func testFeedbackSystemImageGroupsHappyAndErrorStates() {
        XCTAssertEqual(PlannerNotificationResult.scheduled.feedbackSystemImage, "bell.badge.fill")
        XCTAssertEqual(PlannerNotificationResult.disabled.feedbackSystemImage, "bell.slash")

        let errorImage = "exclamationmark.triangle.fill"
        XCTAssertEqual(PlannerNotificationResult.missingDate.feedbackSystemImage, errorImage)
        XCTAssertEqual(PlannerNotificationResult.pastDate.feedbackSystemImage, errorImage)
        XCTAssertEqual(PlannerNotificationResult.permissionDenied.feedbackSystemImage, errorImage)
        XCTAssertEqual(PlannerNotificationResult.failed("x").feedbackSystemImage, errorImage)
    }

    func testFailedEqualityComparesReason() {
        XCTAssertEqual(PlannerNotificationResult.failed("a"), .failed("a"))
        XCTAssertNotEqual(PlannerNotificationResult.failed("a"), .failed("b"))
    }

    // MARK: - Helpers

    private var allRepresentativeResults: [PlannerNotificationResult] {
        [
            .scheduled,
            .disabled,
            .missingDate,
            .pastDate,
            .permissionDenied,
            .failed("network")
        ]
    }

    private func makePlan(
        id: UUID = UUID(),
        reminderEnabled: Bool,
        reminderDate: Date? = nil
    ) -> OutfitPlan {
        OutfitPlan(
            id: id,
            planKind: .daily,
            date: Date.now.addingTimeInterval(86_400),
            title: "测试计划",
            occasion: "通勤",
            outfitSummary: "白衬衫 + 牛仔裤",
            reminderEnabled: reminderEnabled,
            reminderDate: reminderDate
        )
    }
}
