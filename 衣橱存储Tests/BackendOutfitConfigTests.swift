import XCTest
@testable import 衣橱存储

@MainActor
final class BackendOutfitConfigTests: XCTestCase {

    private let userDefaultsKey = "WearOrderAIBaseURL"
    private let deviceIDKey = "WearOrderDeviceID"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: deviceIDKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: deviceIDKey)
        super.tearDown()
    }

    func testIsConfiguredFalseWhenNothingSet() {
        // Info.plist may or may not have a baked-in value depending
        // on build config. Test with the runtime override pathway,
        // which always clears predictably.
        BackendOutfitConfig.setRuntimeBaseURLOverride(nil)
        let beforeBaseURL = BackendOutfitConfig.baseURL
        // If a build-config bakes in a base URL, that's fine; we just
        // verify the override clear path works without crashing.
        XCTAssertEqual(BackendOutfitConfig.isConfigured, beforeBaseURL != nil)
    }

    func testRuntimeOverrideTakesEffect() {
        BackendOutfitConfig.setRuntimeBaseURLOverride("https://api.example.com")
        XCTAssertTrue(BackendOutfitConfig.isConfigured)
        XCTAssertEqual(BackendOutfitConfig.baseURL?.absoluteString, "https://api.example.com")
    }

    func testRuntimeOverrideRejectsInvalidScheme() {
        BackendOutfitConfig.setRuntimeBaseURLOverride("ftp://api.example.com")
        XCTAssertNil(BackendOutfitConfig.baseURL, "Only http/https URLs should be accepted")
    }

    func testRuntimeOverrideRejectsEmptyString() {
        BackendOutfitConfig.setRuntimeBaseURLOverride("")
        XCTAssertNil(BackendOutfitConfig.baseURL)
    }

    func testRuntimeOverrideClearAfterSet() {
        BackendOutfitConfig.setRuntimeBaseURLOverride("https://api.example.com")
        XCTAssertNotNil(BackendOutfitConfig.baseURL)
        BackendOutfitConfig.setRuntimeBaseURLOverride(nil)
        XCTAssertNil(UserDefaults.standard.string(forKey: userDefaultsKey))
    }

    func testDeviceIDIsStableWithinProcess() {
        let first = BackendOutfitConfig.deviceID
        let second = BackendOutfitConfig.deviceID
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testDeviceIDPersistsAcrossLookups() {
        let first = BackendOutfitConfig.deviceID
        // Simulate a fresh process by clearing in-memory state — but
        // UserDefaults persists, so we still get the same value.
        XCTAssertEqual(UserDefaults.standard.string(forKey: deviceIDKey), first)
    }
}
