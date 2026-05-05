import XCTest
@testable import 衣橱存储

@MainActor
final class AIAvailabilityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure tests start from a known state — no cloud override.
        BackendOutfitConfig.setRuntimeBaseURLOverride(nil)
    }

    override func tearDown() {
        BackendOutfitConfig.setRuntimeBaseURLOverride(nil)
        super.tearDown()
    }

    /// Simulator + iOS 17 deployment target — FoundationModels is
    /// missing or reports unavailable, AND we cleared the cloud
    /// override. Both paths off → entry must hide.
    func testIsAvailableIsFalseWithNoOnDeviceAndNoCloud() {
        // Skip if Info.plist bakes in a URL (some build configs do).
        guard !BackendOutfitConfig.isConfigured else {
            return
        }
        XCTAssertFalse(AIAvailability.isAvailable)
        XCTAssertFalse(AIAvailability.isOnDeviceAvailable)
        XCTAssertFalse(AIAvailability.isCloudAvailable)
    }

    /// Setting a cloud URL flips isAvailable to true even when
    /// on-device is unreachable — this is the fix for国行设备.
    func testIsAvailableTrueWhenCloudConfigured() {
        BackendOutfitConfig.setRuntimeBaseURLOverride("https://api.example.com")
        XCTAssertTrue(AIAvailability.isAvailable)
        XCTAssertTrue(AIAvailability.isCloudAvailable)
    }

    func testCurrentStateIsNotAvailableInTestHarness() {
        switch AIAvailability.current {
        case .available:
            XCTFail("Test harness should never report Apple Intelligence as available")
        case .unavailable, .needsNewerOS:
            break
        }
    }

    func testDisabledMessageEmptyWhenCloudConfigured() {
        BackendOutfitConfig.setRuntimeBaseURLOverride("https://api.example.com")
        XCTAssertEqual(AIAvailability.disabledMessage, "")
    }

    func testDisabledMessageIsUserPresentableWhenAllUnavailable() {
        guard !BackendOutfitConfig.isConfigured else { return }
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
