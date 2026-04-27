import XCTest
@testable import 衣橱存储

final class WardrobeOnboardingStateTests: XCTestCase {
    func testFirstRunOnboardingShowsOnlyForEmptyUnseenProductionWardrobe() {
        XCTAssertTrue(
            WardrobeOnboardingState.shouldPresent(
                hasSeenOnboarding: false,
                isPreview: false,
                isEmptyWardrobe: true
            )
        )

        XCTAssertFalse(
            WardrobeOnboardingState.shouldPresent(
                hasSeenOnboarding: true,
                isPreview: false,
                isEmptyWardrobe: true
            )
        )

        XCTAssertFalse(
            WardrobeOnboardingState.shouldPresent(
                hasSeenOnboarding: false,
                isPreview: true,
                isEmptyWardrobe: true
            )
        )

        XCTAssertFalse(
            WardrobeOnboardingState.shouldPresent(
                hasSeenOnboarding: false,
                isPreview: false,
                isEmptyWardrobe: false
            )
        )
    }
}
