import SwiftData
import XCTest
@testable import 衣橱存储

/// Replaces the smoke-test `grep` guards with Swift-level assertions.
///
/// Two flavors of guard live here:
///   1. **Compile-time presence** — typing the symbol forces the compiler to
///      catch deletion or rename. Renaming is fine (CI flags it once); the
///      brittleness of grepping for an exact identifier is gone.
///   2. **Runtime invariants** — values that the compiler cannot enforce, such
///      as the CloudKit container identifier or release contact URLs.
@MainActor
final class AppWiringTests: XCTestCase {

    // MARK: - SwiftData / CloudKit wiring

    func testCloudKitContainerIdentifierMatchesEntitlement() {
        // Must mirror the `iCloud.com.ramsey.wearorder` identifier in
        // 衣橱存储/衣橱存储.entitlements. App Store reviews fail when the
        // entitlement and the runtime container disagree.
        XCTAssertEqual(
            WardrobePersistentStore.cloudKitContainerIdentifier,
            "iCloud.com.ramsey.wearorder"
        )
    }

    func testSwiftDataSchemaIsVersionedAtV1() {
        XCTAssertEqual(WardrobeSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(WardrobeSchemaV1.models.count, 3)
    }

    func testMigrationPlanRegistersV1AsBaseline() {
        XCTAssertEqual(WardrobeMigrationPlan.schemas.count, 1)
        let firstSchema = WardrobeMigrationPlan.schemas.first
        XCTAssertNotNil(firstSchema)
        XCTAssertEqual(
            firstSchema.map(ObjectIdentifier.init),
            ObjectIdentifier(WardrobeSchemaV1.self)
        )
        XCTAssertTrue(WardrobeMigrationPlan.stages.isEmpty, "V1 baseline plan has no migration stages yet")
    }

    func testCloudKitIsDisabledUnderXCTest() {
        // Ensures the test process does NOT hit a real CloudKit container.
        // If this regresses, every local test run starts attempting iCloud
        // network calls.
        XCTAssertFalse(WardrobePersistentStore.shouldUseCloudKit)
    }

    // MARK: - Release contacts

    func testAppReleaseInfoExposesPublicHTTPSPrivacyAndSupportLinks() {
        XCTAssertNotNil(AppReleaseInfo.privacyPolicyURL)
        XCTAssertNotNil(AppReleaseInfo.supportURL)
        XCTAssertEqual(AppReleaseInfo.privacyPolicyURL?.scheme, "https")
        XCTAssertEqual(AppReleaseInfo.supportURL?.scheme, "https")
    }

    func testAppReleaseInfoSupportEmailIsNonEmpty() {
        XCTAssertFalse(AppReleaseInfo.supportEmail.isEmpty)
        XCTAssertTrue(AppReleaseInfo.supportEmail.contains("@"))
    }

    // MARK: - Production gates for unfinished features

    func testAIStylistEntryIsGatedOffInProductionBuild() {
        // INTERNAL_TOOLS is only set in dev configs, so production binaries
        // must hide the AI entry point until Pro is shipped.
        #if INTERNAL_TOOLS
        XCTAssertTrue(AppReleaseInfo.allowsAIStylistEntry)
        #else
        XCTAssertFalse(AppReleaseInfo.allowsAIStylistEntry)
        #endif
    }

    func testSampleDataLoaderIsGatedOffInProductionBuild() {
        #if INTERNAL_TOOLS
        XCTAssertTrue(AppReleaseInfo.allowsSampleDataEntry)
        #else
        XCTAssertFalse(AppReleaseInfo.allowsSampleDataEntry)
        #endif
    }

    // MARK: - Compile-time symbol presence

    /// Touching these symbols causes the compiler to enforce that the public
    /// surface used by the rest of the app still exists. If any of them are
    /// deleted (or renamed without a matching test update), this file fails to
    /// build and CI rejects the change.
    func testCriticalPublicSymbolsRemain() {
        let symbolBag: [Any.Type] = [
            // Core data layer
            WardrobeItem.self,
            OutfitPlan.self,
            OOTDOutfit.self,
            // Backup / repair / health surfaces
            WardrobeBackupManager.self,
            WardrobeDataRepair.self,
            WardrobeDataHealthSnapshot.self,
            // Recommendation engine
            RecommendationEngine.self,
            // Reusable empty / onboarding views
            WardrobeEmptyStateView.self,
            WardrobeOnboardingView.self,
            // App Store metadata models
            AppStoreScreenshotScenario.self,
            WardrobeReleaseQAFlow.self,
            // Image storage
            WardrobeImageFileStore.self,
            WardrobeInlineImageMigrator.self,
            // Notifications
            PlannerNotificationManager.self,
            // Diagnostics
            DiagnosticsStorage.self,
            MetricKitObserver.self
        ]
        XCTAssertFalse(symbolBag.isEmpty)
    }
}
