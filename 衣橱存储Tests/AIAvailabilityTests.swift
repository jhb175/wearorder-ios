import XCTest
@testable import 衣橱存储

@MainActor
final class AIAvailabilityTests: XCTestCase {

    /// Simulator + iOS 17 deployment target — FoundationModels is either
    /// missing entirely (iOS < 26) or reports unavailable on simulator.
    /// Either way, the entry must remain hidden in the test harness so
    /// production builds running on incompatible devices keep the AI UI
    /// gated off.
    func testIsAvailableIsFalseInTestHarness() {
        XCTAssertFalse(AIAvailability.isAvailable)
    }

    func testCurrentStateIsNotAvailableInTestHarness() {
        switch AIAvailability.current {
        case .available:
            XCTFail("Test harness should never report Apple Intelligence as available")
        case .unavailable, .needsNewerOS:
            break
        }
    }

    func testDisabledMessageIsUserPresentableWhenUnavailable() {
        let message = AIAvailability.disabledMessage
        XCTAssertFalse(message.isEmpty, "disabledMessage must guide the user when AI is gated off")
    }

    func testStateIsEquatable() {
        XCTAssertEqual(AIAvailability.State.needsNewerOS, AIAvailability.State.needsNewerOS)
        XCTAssertEqual(
            AIAvailability.State.unavailable(reason: "x"),
            AIAvailability.State.unavailable(reason: "x")
        )
        XCTAssertNotEqual(
            AIAvailability.State.unavailable(reason: "x"),
            AIAvailability.State.unavailable(reason: "y")
        )
    }
}
