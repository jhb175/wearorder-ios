import XCTest
@testable import 衣橱存储

final class WardrobeDestructiveActionGuardTests: XCTestCase {
    func testResetRequiresExactConfirmationPhraseAfterTrimming() {
        XCTAssertTrue(WardrobeDestructiveActionGuard.canConfirmReset(" 清空 "))
        XCTAssertFalse(WardrobeDestructiveActionGuard.canConfirmReset(""))
        XCTAssertFalse(WardrobeDestructiveActionGuard.canConfirmReset("删除"))
        XCTAssertFalse(WardrobeDestructiveActionGuard.canConfirmReset("清空数据"))
    }
}
