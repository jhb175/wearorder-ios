#!/usr/bin/env bash
set -euo pipefail

# Validates that the WearOrder release artifacts are well-formed before
# uploading a TestFlight build:
#
#   * Privacy manifest, Info.plist, entitlements declare required Apple keys
#   * App Store metadata / privacy / release / screenshot / QA / asset docs
#     are present and non-stale
#   * Xcode project-level config (bundle ID, deployment target, test target)
#     is correct
#   * Debug + Release iOS builds compile, build-for-testing succeeds
#   * Asset catalog has no third-party-source filename hints
#
# Source-level "feature wiring" guards used to live here as ~120 grep lines,
# but they coupled smoke results to specific symbol names and blocked safe
# refactors. They have been replaced by:
#   * `xcodebuild build` (this script) catches anything compile-required.
#   * `xcodebuild test` runs unit tests for behavior.
#   * `衣橱存储Tests/AppWiringTests.swift` covers the few wiring invariants
#     (CloudKit container ID, release contact URLs) the compiler can't see.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'Smoke test failed: %s\n' "$1" >&2
  exit 1
}

PROJECT_FILE="衣橱存储.xcodeproj/project.pbxproj"
APP_DIR="衣橱存储"
PRIVACY_MANIFEST="$APP_DIR/PrivacyInfo.xcprivacy"
INFO_PLIST="$APP_DIR/Info.plist"

# ---------------------------------------------------------------------------
# 1. File existence + plist validity
# ---------------------------------------------------------------------------

[ -f "$PRIVACY_MANIFEST" ] \
  || fail "PrivacyInfo.xcprivacy is missing"

[ -f "$INFO_PLIST" ] \
  || fail "Info.plist is missing"

plutil -lint "$INFO_PLIST" >/dev/null \
  || fail "Info.plist is not a valid plist"

plutil -lint "$PRIVACY_MANIFEST" >/dev/null \
  || fail "PrivacyInfo.xcprivacy is not a valid plist"

# ---------------------------------------------------------------------------
# 2. Privacy manifest required keys (Apple-mandatory)
# ---------------------------------------------------------------------------

grep -q 'NSPrivacyAccessedAPICategoryUserDefaults' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare UserDefaults required reason API"

grep -q '<string>CA92.1</string>' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare the app-only UserDefaults reason"

grep -q 'NSPrivacyAccessedAPICategoryFileTimestamp' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare file metadata required reason API"

grep -q '<string>C617.1</string>' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare the app-container file metadata reason"

grep -q 'NSPrivacyCollectedDataTypes' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare collected data types"

grep -q 'NSPrivacyTracking' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare tracking status"

grep -q 'NSPrivacyCollectedDataTypePreciseLocation' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare location collection for weather"

grep -q 'NSPrivacyCollectedDataTypeEmailAddress' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare Apple ID email collection"

grep -q 'NSPrivacyCollectedDataTypeUserID' "$PRIVACY_MANIFEST" \
  || fail "privacy manifest does not declare Apple ID user identifier collection"

# ---------------------------------------------------------------------------
# 3. Info.plist required descriptions + background modes
# ---------------------------------------------------------------------------

grep -q 'NSLocationWhenInUseUsageDescription' "$INFO_PLIST" \
  || fail "Info.plist does not include location usage description"

grep -q 'NSCameraUsageDescription' "$INFO_PLIST" \
  || fail "camera usage description is missing"

grep -q '<key>ITSAppUsesNonExemptEncryption</key>' "$INFO_PLIST" \
  || fail "export compliance key is missing"

grep -q '<key>UIBackgroundModes</key>' "$INFO_PLIST" \
  || fail "Info.plist does not declare background modes"

grep -q '<string>remote-notification</string>' "$INFO_PLIST" \
  || fail "remote notification background mode is missing for CloudKit sync"

# ---------------------------------------------------------------------------
# 4. Entitlements (Apple capabilities)
# ---------------------------------------------------------------------------

grep -q 'com.apple.developer.applesignin' "$APP_DIR/衣橱存储.entitlements" \
  || fail "Sign in with Apple entitlement is missing"

grep -q 'com.apple.developer.weatherkit' "$APP_DIR/衣橱存储.entitlements" \
  || fail "WeatherKit entitlement is missing"

grep -q 'com.apple.developer.icloud-services' "$APP_DIR/衣橱存储.entitlements" \
  || fail "CloudKit iCloud service entitlement is missing"

grep -q 'iCloud.com.ramsey.wearorder' "$APP_DIR/衣橱存储.entitlements" \
  || fail "CloudKit container identifier is missing"

# ---------------------------------------------------------------------------
# 5. Xcode project config
# ---------------------------------------------------------------------------

grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.ramsey.wearorder;' "$PROJECT_FILE" \
  || fail "bundle identifier is not set to the release placeholder replacement"

grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 17.0;' "$PROJECT_FILE" \
  || fail "iOS deployment target is not 17.0"

grep -q 'SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";' "$PROJECT_FILE" \
  || fail "supported platforms are not limited to iOS"

grep -q '衣橱存储Tests' "$PROJECT_FILE" \
  || fail "XCTest target is missing from the Xcode project"

# ---------------------------------------------------------------------------
# 6. App Store / release documentation contracts
# ---------------------------------------------------------------------------

[ -f "PRIVACY.md" ] \
  || fail "privacy policy draft is missing"

grep -q '不接入广告追踪' "PRIVACY.md" \
  || fail "privacy policy does not state tracking posture"

grep -q 'Apple ID 登录' "PRIVACY.md" \
  || fail "privacy policy does not describe Sign in with Apple"

[ -f "APP_STORE_METADATA.md" ] \
  || fail "App Store metadata draft is missing"

grep -q 'Bundle ID：com.ramsey.wearorder' "APP_STORE_METADATA.md" \
  || fail "App Store metadata does not include bundle ID"

grep -q 'configure_release_contacts.sh' "APP_STORE_METADATA.md" \
  || fail "App Store metadata does not document release contact configuration"

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

# ---------------------------------------------------------------------------
# 7. Asset catalog license hygiene
# ---------------------------------------------------------------------------

grep -q '"filename" : "AppIcon.png"' "$APP_DIR/Assets.xcassets/AppIcon.appiconset/Contents.json" \
  || fail "app icon filename is missing"

if find "$APP_DIR/Assets.xcassets" -type f | grep -E '小红书|水印|来自|download|web|网页版|unsplash|pexels|素材' >/dev/null; then
  fail "Assets.xcassets contains filenames that need license review"
fi

# ---------------------------------------------------------------------------
# 8. Build verification (Debug iOS, build-for-testing simulator, Release iOS)
#    These catch any genuine wiring breakage that the compiler can detect.
# ---------------------------------------------------------------------------

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
