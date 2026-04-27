#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'Smoke test failed: %s\n' "$1" >&2
  exit 1
}

PROJECT_FILE="衣橱存储.xcodeproj/project.pbxproj"
APP_DIR="衣橱存储"
PRIVACY_MANIFEST="$APP_DIR/PrivacyInfo.xcprivacy"

[ -f "$PRIVACY_MANIFEST" ] \
  || fail "PrivacyInfo.xcprivacy is missing"

plutil -lint "$PRIVACY_MANIFEST" >/dev/null \
  || fail "PrivacyInfo.xcprivacy is not a valid plist"

grep -q 'NSPrivacyAccessedAPICategoryUserDefaults' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare UserDefaults required reason API"

grep -q '<string>CA92.1</string>' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare the app-only UserDefaults reason"

grep -q 'NSPrivacyCollectedDataTypes' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare collected data types"

grep -q 'NSPrivacyTracking' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare tracking status"

grep -q 'NSPrivacyCollectedDataTypePreciseLocation' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare location collection for weather"

[ -f "PRIVACY.md" ] \
  || fail "privacy policy draft is missing"

grep -q '不接入广告追踪' "PRIVACY.md" \
  || fail "privacy policy does not state tracking posture"

[ -f "APP_STORE_METADATA.md" ] \
  || fail "App Store metadata draft is missing"

grep -q 'Bundle ID：com.ramsey.wearorder' "APP_STORE_METADATA.md" \
  || fail "App Store metadata does not include bundle ID"

grep -q 'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription' "$PROJECT_FILE" \
  || fail "project does not include location usage description"

[ -f "APP_STORE_CONNECT_PRIVACY_LABELS.md" ] \
  || fail "App Store Connect privacy label guide is missing"

grep -q 'Precise Location' "APP_STORE_CONNECT_PRIVACY_LABELS.md" \
  || fail "App Store Connect privacy label guide does not disclose location usage"

[ -f "RELEASE_CHECKLIST.md" ] \
  || fail "release checklist is missing"

grep -q 'TestFlight' "RELEASE_CHECKLIST.md" \
  || fail "release checklist does not include TestFlight checks"

[ -f "RELEASE_NOTES.md" ] \
  || fail "release notes are missing"

grep -q '衣序 WearOrder 1.0 发布说明' "RELEASE_NOTES.md" \
  || fail "release notes do not describe version 1.0"

[ -f "ASSET_LICENSES.md" ] \
  || fail "asset license record is missing"

grep -q 'AppIcon.png' "ASSET_LICENSES.md" \
  || fail "asset license record does not include the app icon"

[ -f "APP_STORE_SCREENSHOTS.md" ] \
  || fail "App Store screenshot plan is missing"

grep -q 'App Store 1 · 首页总览' "APP_STORE_SCREENSHOTS.md" \
  || fail "App Store screenshot plan does not include the home screenshot"

grep -q 'App Store 5 · 隐私支持' "APP_STORE_SCREENSHOTS.md" \
  || fail "App Store screenshot plan does not include the privacy/support screenshot"

[ -f "APP_STORE_QA.md" ] \
  || fail "App Store QA checklist is missing"

grep -q '首次启动' "APP_STORE_QA.md" \
  || fail "App Store QA checklist does not include first-launch verification"

grep -q '备份恢复' "APP_STORE_QA.md" \
  || fail "App Store QA checklist does not include backup restore verification"

[ -x "scripts/audit_app_store_readiness.sh" ] \
  || fail "App Store readiness audit script is missing or not executable"

[ -x "scripts/configure_release_contacts.sh" ] \
  || fail "release contact configuration script is missing or not executable"

grep -q 'configure_release_contacts.sh' "APP_STORE_METADATA.md" \
  || fail "App Store metadata does not document release contact configuration"

grep -q 'validate_public_https_url' "scripts/configure_release_contacts.sh" \
  || fail "release contact configuration script does not validate HTTPS URLs"

grep -q 'validate_email' "scripts/configure_release_contacts.sh" \
  || fail "release contact configuration script does not validate support email"

./scripts/configure_release_contacts.sh \
  --dry-run \
  --privacy-url https://privacy.wearorder.app/privacy \
  --support-url https://support.wearorder.app/help \
  --support-email support@wearorder.app >/dev/null \
  || fail "release contact configuration dry-run failed"

grep -q 'enum AppReleaseInfo' "$APP_DIR/AppReleaseInfo.swift" \
  || fail "release contact configuration model is missing"

grep -q 'enum AppStoreScreenshotScenario' "$APP_DIR/AppStoreScreenshotScenario.swift" \
  || fail "App Store screenshot scenario model is missing"

grep -q 'enum WardrobeReleaseQAFlow' "$APP_DIR/WardrobeReleaseQAChecklist.swift" \
  || fail "release QA checklist model is missing"

grep -q './scripts/audit_app_store_readiness.sh --strict' "$APP_DIR/WardrobeReleaseQAChecklist.swift" \
  || fail "release QA checklist does not require the strict App Store audit"

grep -q 'WardrobePreviewContainer.make()' "$APP_DIR/AppStoreScreenshotPreviews.swift" \
  || fail "App Store screenshot previews do not use isolated preview data"

grep -q 'App Store 3 · 智能推荐' "$APP_DIR/AppStoreScreenshotPreviews.swift" \
  || fail "App Store screenshot previews do not include recommendation scene"

grep -q 'privacyPolicyURLString' "$APP_DIR/AppReleaseInfo.swift" \
  || fail "release contact configuration does not include privacy policy URL"

grep -q 'supportURLString' "$APP_DIR/AppReleaseInfo.swift" \
  || fail "release contact configuration does not include support URL"

grep -q 'supportEmail' "$APP_DIR/AppReleaseInfo.swift" \
  || fail "release contact configuration does not include support email"

grep -q 'AppReleaseInfo.privacyPolicyURL' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings view does not expose the public privacy policy URL"

grep -q 'AppReleaseInfo.supportURL' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings view does not expose the public support URL"

grep -q '隐私与支持' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings privacy section is not user-facing"

grep -q '本地隐私承诺' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings view does not explain the local privacy posture"

if grep -q '隐私与上架\|PrivacyInfo.xcprivacy 声明' "$APP_DIR/WardrobeSettingsView.swift"; then
  fail "settings view still exposes developer-facing privacy/release wording"
fi

if grep -q '尚未接入 UserNotifications 真正触发\|OOTD 详情占位\|下一阶段这里会接入' "$APP_DIR/ContentView.swift"; then
  fail "ContentView still contains stale placeholder copy"
fi

grep -q 'AppReleaseInfoTests' "衣橱存储Tests/AppReleaseInfoTests.swift" \
  || fail "release contact XCTest coverage is missing"

grep -q 'AppStoreScreenshotScenarioTests' "衣橱存储Tests/AppStoreScreenshotScenarioTests.swift" \
  || fail "App Store screenshot scenario XCTest coverage is missing"

grep -q 'WardrobeReleaseQAChecklistTests' "衣橱存储Tests/WardrobeReleaseQAChecklistTests.swift" \
  || fail "release QA checklist XCTest coverage is missing"

grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.ramsey.wearorder;' "$PROJECT_FILE" \
  || fail "bundle identifier is not set to the release placeholder replacement"

grep -q 'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;' "$PROJECT_FILE" \
  || fail "export compliance key is missing"

grep -q 'INFOPLIST_KEY_NSCameraUsageDescription' "$PROJECT_FILE" \
  || fail "camera usage description is missing"

grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 17.0;' "$PROJECT_FILE" \
  || fail "iOS deployment target is not 17.0"

grep -q 'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";' "$PROJECT_FILE" \
  || fail "supported platforms are not limited to iOS"

grep -q '衣橱存储Tests' "$PROJECT_FILE" \
  || fail "XCTest target is missing from the Xcode project"

grep -q 'WardrobeBackupManagerTests' "衣橱存储Tests/WardrobeBackupManagerTests.swift" \
  || fail "wardrobe backup XCTest coverage is missing"

grep -q 'RecommendationEngineTests' "衣橱存储Tests/RecommendationEngineTests.swift" \
  || fail "recommendation engine XCTest coverage is missing"

grep -q 'WardrobeDataHealthTests' "衣橱存储Tests/WardrobeDataHealthTests.swift" \
  || fail "data health XCTest coverage is missing"

grep -q 'WardrobeDataRepairTests' "衣橱存储Tests/WardrobeDataRepairTests.swift" \
  || fail "data repair XCTest coverage is missing"

grep -q 'WardrobeOnboardingStateTests' "衣橱存储Tests/WardrobeOnboardingStateTests.swift" \
  || fail "onboarding state XCTest coverage is missing"

grep -q 'DeletionImpactSummaryTests' "衣橱存储Tests/DeletionImpactSummaryTests.swift" \
  || fail "deletion impact XCTest coverage is missing"

grep -q 'WardrobeCoreFlowReadinessTests' "衣橱存储Tests/WardrobeCoreFlowReadinessTests.swift" \
  || fail "core flow readiness XCTest coverage is missing"

grep -q 'ImageDataOptimizerTests' "衣橱存储Tests/ImageDataOptimizerTests.swift" \
  || fail "image optimizer XCTest coverage is missing"

grep -q 'ClosetOrganizationSnapshotTests' "衣橱存储Tests/ClosetOrganizationSnapshotTests.swift" \
  || fail "closet organization XCTest coverage is missing"

grep -q 'OOTDLibrarySnapshotTests' "衣橱存储Tests/OOTDLibrarySnapshotTests.swift" \
  || fail "OOTD library XCTest coverage is missing"

grep -q 'PlannerReminderSummaryTests' "衣橱存储Tests/PlannerReminderSummaryTests.swift" \
  || fail "planner reminder XCTest coverage is missing"

grep -q 'WardrobeDestructiveActionGuardTests' "衣橱存储Tests/WardrobeDestructiveActionGuardTests.swift" \
  || fail "destructive action guard XCTest coverage is missing"

if grep -R 'seedMockDataIfNeeded' "$APP_DIR" >/dev/null; then
  fail "automatic mock data seeding is still present"
fi

grep -q 'loadSampleData()' "$APP_DIR/ContentView.swift" \
  || fail "manual sample data loading entry is missing"

grep -q '@AppStorage(WardrobeOnboardingState.storageKey)' "$APP_DIR/ContentView.swift" \
  || fail "first-run onboarding persistence is not wired"

grep -q 'presentFirstRunOnboardingIfNeeded' "$APP_DIR/ContentView.swift" \
  || fail "first-run onboarding presentation is missing"

grep -q 'struct WardrobeOnboardingView' "$APP_DIR/WardrobeOnboardingView.swift" \
  || fail "first-run onboarding view is missing"

grep -q 'enum WardrobeOnboardingState' "$APP_DIR/WardrobeOnboardingState.swift" \
  || fail "first-run onboarding state model is missing"

grep -q 'struct WardrobeEmptyStateView' "$APP_DIR/WardrobeEmptyStateView.swift" \
  || fail "reusable empty state view is missing"

grep -q 'WardrobeEmptyStateView' "$APP_DIR/ClosetView.swift" \
  || fail "closet empty state is not using reusable empty state"

grep -q 'WardrobeEmptyStateView' "$APP_DIR/PlannerView.swift" \
  || fail "planner empty state is not using reusable empty state"

grep -q 'WardrobeSettingsView' "$APP_DIR/ContentView.swift" \
  || fail "settings tab is not wired into the main app"

grep -q 'struct WardrobeSettingsView' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings view is missing"

grep -q 'showsOnboarding' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings view cannot reopen onboarding"

grep -q 'WardrobeDataHealthSnapshot.make' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings view does not run data health checks"

grep -q 'WardrobeDataRepair.apply' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings view does not expose automatic data repair"

grep -q 'dangerZoneSection' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings dangerous operations section is missing"

grep -q 'WardrobeResetConfirmationView' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings reset confirmation view is missing"

grep -q 'resetAllLocalData' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings reset operation is missing"

grep -q 'enum WardrobeDestructiveActionGuard' "$APP_DIR/WardrobeDestructiveActionGuard.swift" \
  || fail "destructive action guard is missing"

grep -q 'enum WardrobeDataRepair' "$APP_DIR/WardrobeDataRepair.swift" \
  || fail "data repair model is missing"

grep -q 'enum WardrobeSampleDataLoader' "$APP_DIR/WardrobeSampleDataLoader.swift" \
  || fail "shared sample data loader is missing"

grep -q 'WardrobeNotificationSynchronizer.synchronizeImportedNotifications' "$APP_DIR/WardrobeSettingsView.swift" \
  || fail "settings backup restore does not resync imported notifications"

grep -q 'handleQuickAction(action)' "$APP_DIR/ContentView.swift" \
  || fail "home quick actions are not wired"

grep -q 'startCreateOOTDFlow' "$APP_DIR/ContentView.swift" \
  || fail "home OOTD creation is not guarded by core flow readiness"

grep -q 'startCreatePlanFlow' "$APP_DIR/ContentView.swift" \
  || fail "home plan creation is not guarded by core flow readiness"

grep -q 'sourceLabel: weatherSourceLabel' "$APP_DIR/ContentView.swift" \
  || fail "home weather source label is missing"

grep -q 'WeatherForecastService' "$APP_DIR/ContentView.swift" \
  || fail "home weather does not use the forecast service"

grep -q '按今日预报去搭配' "$APP_DIR/ContentView.swift" \
  || fail "home weather recommendation action does not use forecast wording"

grep -q 'ImageDataOptimizer.optimizedJPEGData' "$APP_DIR/ClothingEditorForm.swift" \
  || fail "photo import does not use image optimization"

grep -q 'CameraCaptureView' "$APP_DIR/ClothingEditorForm.swift" \
  || fail "clothing editor does not expose camera capture"

grep -q 'struct CameraCaptureView' "$APP_DIR/CameraCaptureView.swift" \
  || fail "camera capture bridge is missing"

grep -q 'ClothingImageImportStatus' "$APP_DIR/ClothingEditorForm.swift" \
  || fail "photo import status is missing"

grep -q 'usageSummarySection' "$APP_DIR/ClothingDetailView.swift" \
  || fail "clothing detail usage summary is missing"

grep -q 'linkedPlansSection' "$APP_DIR/ClothingDetailView.swift" \
  || fail "clothing detail linked plans section is missing"

grep -q 'WardrobeExporter.itemReport' "$APP_DIR/ClothingDetailView.swift" \
  || fail "clothing detail export action is missing"

grep -q 'deletionImpactSection' "$APP_DIR/ClothingDetailView.swift" \
  || fail "clothing detail deletion impact section is missing"

grep -q 'static func itemReport' "$APP_DIR/WardrobeExporter.swift" \
  || fail "clothing item report exporter is missing"

grep -q 'WardrobeExporter.plainText' "$APP_DIR/ClosetView.swift" \
  || fail "closet export action is missing"

grep -q 'WardrobeExporter.fullReport' "$APP_DIR/ContentView.swift" \
  || fail "home full data export action is missing"

grep -q 'WardrobeBackupManager.makeBackupFile' "$APP_DIR/ContentView.swift" \
  || fail "home JSON backup export is not wired"

grep -q 'fileExporter' "$APP_DIR/ContentView.swift" \
  || fail "JSON backup file exporter is missing"

grep -q 'fileImporter' "$APP_DIR/ContentView.swift" \
  || fail "JSON backup file importer is missing"

grep -q 'static func fullReport' "$APP_DIR/WardrobeExporter.swift" \
  || fail "full report exporter is missing"

grep -q 'enum WardrobeBackupManager' "$APP_DIR/WardrobeBackupManager.swift" \
  || fail "JSON backup manager is missing"

grep -q 'static func exportData' "$APP_DIR/WardrobeBackupManager.swift" \
  || fail "JSON backup export encoder is missing"

grep -q 'static func restore' "$APP_DIR/WardrobeBackupManager.swift" \
  || fail "JSON backup restore decoder is missing"

grep -q 'plansForNotificationSync' "$APP_DIR/WardrobeBackupManager.swift" \
  || fail "JSON backup restore does not resync planner notifications"

grep -q 'closetOrganizationSection' "$APP_DIR/ClosetView.swift" \
  || fail "closet organization insights are missing"

grep -q 'closetCoverageSection' "$APP_DIR/ClosetView.swift" \
  || fail "closet category coverage section is missing"

grep -q 'ClosetOrganizationSnapshot.make' "$APP_DIR/ClosetView.swift" \
  || fail "closet organization snapshot is not wired"

grep -q 'case needsDetails' "$APP_DIR/ClosetView.swift" \
  || fail "closet missing details filter is missing"

grep -q 'struct ClosetOrganizationSnapshot' "$APP_DIR/ClosetOrganizationSnapshot.swift" \
  || fail "closet organization snapshot model is missing"

grep -q 'ClosetFocusFilter.allCases' "$APP_DIR/ClosetView.swift" \
  || fail "closet focus filters are missing"

grep -q 'ClosetSortMode.allCases' "$APP_DIR/ClosetView.swift" \
  || fail "closet sorting control is missing"

grep -q 'PlannerQuickTemplate.allCases' "$APP_DIR/PlannerView.swift" \
  || fail "planner quick templates are missing"

grep -q 'planToolsSection' "$APP_DIR/PlannerView.swift" \
  || fail "planner search and filter tools are missing"

grep -q 'plannerReminderStatusSection' "$APP_DIR/PlannerView.swift" \
  || fail "planner reminder status section is missing"

grep -q 'clearInvalidReminders' "$APP_DIR/PlannerView.swift" \
  || fail "planner invalid reminder cleanup is missing"

grep -q 'struct PlannerReminderSummary' "$APP_DIR/PlannerReminderSummary.swift" \
  || fail "planner reminder summary model is missing"

grep -q 'PlannerFocusFilter.allCases' "$APP_DIR/PlannerView.swift" \
  || fail "planner focus filters are missing"

grep -q 'case conflicting' "$APP_DIR/PlannerView.swift" \
  || fail "planner same-day conflict filter is missing"

grep -q 'sameDayPlanCount(for:' "$APP_DIR/PlannerView.swift" \
  || fail "planner conflict count helper is missing"

grep -q 'PlannerSortMode.allCases' "$APP_DIR/PlannerView.swift" \
  || fail "planner sort control is missing"

grep -q 'WardrobeExporter.plansReport' "$APP_DIR/PlannerView.swift" \
  || fail "planner export action is missing"

grep -q 'static func plansReport' "$APP_DIR/WardrobeExporter.swift" \
  || fail "planner report exporter is missing"

grep -q 'CreatePlanView(draft:' "$APP_DIR/PlannerView.swift" \
  || fail "planner quick drafts are not wired into create plan"

grep -q 'WardrobeCoreFlowReadiness.make' "$APP_DIR/PlannerView.swift" \
  || fail "planner does not preflight core flow readiness"

grep -q 'reusePlanForNextTime' "$APP_DIR/PlanDetailView.swift" \
  || fail "plan detail quick reuse action is missing"

grep -q 'sameDayPlansSection' "$APP_DIR/PlanDetailView.swift" \
  || fail "plan detail same-day plans section is missing"

grep -q 'deletionImpactSection' "$APP_DIR/PlanDetailView.swift" \
  || fail "plan detail deletion impact section is missing"

grep -q 'visibleOOTDOutfits' "$APP_DIR/ContentView.swift" \
  || fail "OOTD filtering list is missing"

grep -q 'ootdSearchText' "$APP_DIR/ContentView.swift" \
  || fail "OOTD search field is missing"

grep -q 'OOTDStarterTemplate.allCases' "$APP_DIR/ContentView.swift" \
  || fail "OOTD starter templates are not wired"

grep -q 'ootdLibraryHealthSection' "$APP_DIR/ContentView.swift" \
  || fail "OOTD library health section is missing"

grep -q 'case unplanned' "$APP_DIR/ContentView.swift" \
  || fail "OOTD unplanned filter is missing"

grep -q 'struct OOTDLibrarySnapshot' "$APP_DIR/OOTDLibrarySnapshot.swift" \
  || fail "OOTD library snapshot model is missing"

grep -q 'enum OOTDStarterTemplate' "$APP_DIR/OOTDStarterTemplate.swift" \
  || fail "OOTD starter template model is missing"

grep -q 'linkedPlansSection' "$APP_DIR/OOTDDetailView.swift" \
  || fail "OOTD detail linked plans section is missing"

grep -q 'WardrobeExporter.outfitReport' "$APP_DIR/OOTDDetailView.swift" \
  || fail "OOTD detail export action is missing"

grep -q 'ootdRequirementBanner' "$APP_DIR/CreateOOTDView.swift" \
  || fail "OOTD creator does not explain missing required clothing"

grep -q 'deletionImpactSection' "$APP_DIR/OOTDDetailView.swift" \
  || fail "OOTD detail deletion impact section is missing"

grep -q 'static func outfitReport' "$APP_DIR/WardrobeExporter.swift" \
  || fail "OOTD report exporter is missing"

grep -q 'removePendingNotificationRequests' "$APP_DIR/PlannerNotificationManager.swift" \
  || fail "notification rescheduling does not clear old pending requests"

grep -q 'temperatureCelsius' "$APP_DIR/RecommendationEngine.swift" \
  || fail "recommendation input does not include temperature"

grep -q 'RecommendationInsight' "$APP_DIR/RecommendationEngine.swift" \
  || fail "recommendation explanations are missing"

grep -q 'RecommendationWardrobeGap' "$APP_DIR/RecommendationEngine.swift" \
  || fail "recommendation wardrobe gap hints are missing"

grep -q 'wardrobeGapSection' "$APP_DIR/RecommendationResultView.swift" \
  || fail "recommendation result does not show wardrobe gaps"

grep -q '推荐依据' "$APP_DIR/RecommendationResultView.swift" \
  || fail "recommendation result does not show explanation details"

grep -q 'existingSavedOutfit(for:' "$APP_DIR/RecommendationResultView.swift" \
  || fail "recommendation saving does not reuse existing outfits"

grep -q 'savedStatusText(for:' "$APP_DIR/RecommendationResultView.swift" \
  || fail "recommendation result saved state is missing"

grep -q '"filename" : "AppIcon.png"' "$APP_DIR/Assets.xcassets/AppIcon.appiconset/Contents.json" \
  || fail "app icon filename is missing"

if find "$APP_DIR/Assets.xcassets" -type f | grep -E '小红书|水印|来自|download|web|网页版|unsplash|pexels|素材' >/dev/null; then
  fail "Assets.xcassets contains filenames that need license review"
fi

xcodebuild \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/yichu-smoke-derived \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build

xcodebuild \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/yichu-smoke-derived \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build-for-testing

xcodebuild \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/yichu-smoke-release-derived \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build

printf 'Local smoke tests passed.\n'
