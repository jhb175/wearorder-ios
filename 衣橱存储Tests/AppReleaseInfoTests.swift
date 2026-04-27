import XCTest
@testable import 衣橱存储

final class AppReleaseInfoTests: XCTestCase {
    func testPublicHTTPSURLValidation() {
        XCTAssertNotNil(AppReleaseInfo.makePublicHTTPSURL("https://example.com/privacy"))
        XCTAssertNotNil(AppReleaseInfo.makePublicHTTPSURL(" https://support.example.com/help "))

        XCTAssertNil(AppReleaseInfo.makePublicHTTPSURL(""))
        XCTAssertNil(AppReleaseInfo.makePublicHTTPSURL("http://example.com/privacy"))
        XCTAssertNil(AppReleaseInfo.makePublicHTTPSURL("https://localhost/privacy"))
        XCTAssertNil(AppReleaseInfo.makePublicHTTPSURL("mailto:support@example.com"))
    }

    func testSupportEmailValidation() {
        XCTAssertTrue(AppReleaseInfo.isValidSupportEmail("support@example.com"))
        XCTAssertTrue(AppReleaseInfo.isValidSupportEmail(" support@example.co "))

        XCTAssertFalse(AppReleaseInfo.isValidSupportEmail(""))
        XCTAssertFalse(AppReleaseInfo.isValidSupportEmail("support"))
        XCTAssertFalse(AppReleaseInfo.isValidSupportEmail("support@example"))
        XCTAssertFalse(AppReleaseInfo.isValidSupportEmail("support @example.com"))
    }

    func testReleaseContactConfigurationStatusMatchesCurrentValues() {
        if AppReleaseInfo.isPublicReleaseContactConfigured {
            XCTAssertNotNil(AppReleaseInfo.privacyPolicyURL)
            XCTAssertNotNil(AppReleaseInfo.supportURL)
            XCTAssertTrue(AppReleaseInfo.isValidSupportEmail(AppReleaseInfo.supportEmail))
            XCTAssertTrue(AppReleaseInfo.missingReleaseContactItems.isEmpty)
            XCTAssertEqual(AppReleaseInfo.releaseContactStatusTitle, "隐私与支持已配置")
        } else {
            XCTAssertFalse(AppReleaseInfo.missingReleaseContactItems.isEmpty)
            XCTAssertEqual(AppReleaseInfo.releaseContactStatusTitle, "隐私与支持待配置")
            XCTAssertTrue(
                AppReleaseInfo.missingReleaseContactItems.allSatisfy {
                    ["隐私政策 HTTPS URL", "支持页面 HTTPS URL", "支持邮箱"].contains($0)
                }
            )
        }
    }
}
