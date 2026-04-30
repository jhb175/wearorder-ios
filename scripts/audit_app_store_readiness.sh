#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

ISSUES=0

issue() {
  ISSUES=$((ISSUES + 1))
  printf 'App Store readiness issue: %s\n' "$1" >&2
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    issue "missing required file: $path"
  fi
}

contains_placeholder() {
  local path="$1"
  local pattern="$2"
  [[ -f "$path" ]] && grep -Eq "$pattern" "$path"
}

require_file "APP_STORE_METADATA.md"
require_file "APP_STORE_CONNECT_PRIVACY_LABELS.md"
require_file "PRIVACY.md"
require_file "RELEASE_CHECKLIST.md"
require_file "ASSET_LICENSES.md"
require_file "APP_STORE_SCREENSHOTS.md"
require_file "APP_STORE_QA.md"
require_file "docs/privacy-policy.html"
require_file "docs/support.html"
require_file "scripts/configure_release_contacts.sh"
require_file "衣橱存储/AppReleaseInfo.swift"
require_file "衣橱存储/PrivacyInfo.xcprivacy"

swift_release_value() {
  local key="$1"
  sed -n "s/.*static let ${key} = \"\\(.*\\)\".*/\\1/p" "衣橱存储/AppReleaseInfo.swift" | head -n 1
}

if contains_placeholder "APP_STORE_METADATA.md" '待填写|待部署|TODO|example\.com'; then
  issue "APP_STORE_METADATA.md still contains placeholder URL/email fields"
fi

if contains_placeholder "docs/privacy-policy.html" '替换为开发者支持邮箱|TODO|example\.com'; then
  issue "docs/privacy-policy.html still contains placeholder contact information"
fi

if contains_placeholder "docs/support.html" '替换为真实|请在上架前|TODO|example\.com'; then
  issue "docs/support.html still contains placeholder support information"
fi

if ! grep -q 'Privacy Policy URL' "APP_STORE_METADATA.md"; then
  issue "APP_STORE_METADATA.md does not contain Privacy Policy URL"
fi

if ! grep -q 'Support URL' "APP_STORE_METADATA.md"; then
  issue "APP_STORE_METADATA.md does not contain Support URL"
fi

if ! grep -q 'Precise Location' "APP_STORE_CONNECT_PRIVACY_LABELS.md"; then
  issue "APP_STORE_CONNECT_PRIVACY_LABELS.md does not disclose weather location usage"
fi

PRIVACY_POLICY_URL="$(swift_release_value "privacyPolicyURLString")"
SUPPORT_URL="$(swift_release_value "supportURLString")"
SUPPORT_EMAIL="$(swift_release_value "supportEmail")"

if [[ ! "$PRIVACY_POLICY_URL" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]]; then
  issue "AppReleaseInfo.swift does not contain a public HTTPS privacy policy URL"
fi

if [[ ! "$SUPPORT_URL" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]]; then
  issue "AppReleaseInfo.swift does not contain a public HTTPS support URL"
fi

if [[ ! "$SUPPORT_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
  issue "AppReleaseInfo.swift does not contain a valid support email"
fi

if ! grep -q '不接入广告追踪' "PRIVACY.md"; then
  issue "PRIVACY.md does not state tracking posture"
fi

if ! grep -q 'NSPrivacyTracking' "衣橱存储/PrivacyInfo.xcprivacy"; then
  issue "PrivacyInfo.xcprivacy does not declare tracking status"
fi

if ! grep -q 'NSPrivacyAccessedAPICategoryFileTimestamp' "衣橱存储/PrivacyInfo.xcprivacy"; then
  issue "PrivacyInfo.xcprivacy does not declare file metadata required reason API"
fi

if ! grep -q '<string>C617.1</string>' "衣橱存储/PrivacyInfo.xcprivacy"; then
  issue "PrivacyInfo.xcprivacy does not declare app-container file metadata reason C617.1"
fi

if ! grep -q 'NSPrivacyCollectedDataTypePreciseLocation' "衣橱存储/PrivacyInfo.xcprivacy"; then
  issue "PrivacyInfo.xcprivacy does not declare precise location collection for weather"
fi

if ! grep -q 'NSPrivacyCollectedDataTypeEmailAddress' "衣橱存储/PrivacyInfo.xcprivacy"; then
  issue "PrivacyInfo.xcprivacy does not declare Apple ID email collection"
fi

if ! grep -q 'NSPrivacyCollectedDataTypeUserID' "衣橱存储/PrivacyInfo.xcprivacy"; then
  issue "PrivacyInfo.xcprivacy does not declare Apple ID user identifier collection"
fi

if ! grep -q 'Apple ID 登录' "PRIVACY.md"; then
  issue "PRIVACY.md does not describe Sign in with Apple account data"
fi

if ! grep -q 'NSLocationWhenInUseUsageDescription' "衣橱存储/Info.plist"; then
  issue "Info.plist does not contain NSLocationWhenInUseUsageDescription for weather"
fi

if grep -R -q -E 'Open-Meteo|api\.open-meteo|geocoding-api\.open-meteo' "衣橱存储" "APP_STORE_METADATA.md" "PRIVACY.md" "docs" "APP_STORE_CONNECT_PRIVACY_LABELS.md"; then
  issue "release materials or app code still reference Open-Meteo instead of WeatherKit"
fi

if ! grep -q 'import WeatherKit' "衣橱存储/WeatherForecastService.swift"; then
  issue "weather forecast service does not import WeatherKit"
fi

if ! grep -q 'com.apple.developer.weatherkit' "衣橱存储/衣橱存储.entitlements"; then
  issue "WeatherKit entitlement is missing from the app entitlements file"
fi

if ! grep -q 'com.apple.developer.applesignin' "衣橱存储/衣橱存储.entitlements"; then
  issue "Sign in with Apple entitlement is missing from the app entitlements file"
fi

if ! grep -q 'com.apple.developer.icloud-services' "衣橱存储/衣橱存储.entitlements"; then
  issue "CloudKit iCloud service entitlement is missing from the app entitlements file"
fi

if ! grep -q 'iCloud.com.ramsey.wearorder' "衣橱存储/衣橱存储.entitlements"; then
  issue "CloudKit container identifier is missing from the app entitlements file"
fi

if ! grep -q '<string>remote-notification</string>' "衣橱存储/Info.plist"; then
  issue "remote notification background mode is missing for CloudKit sync"
fi

if ! grep -q 'cloudKitDatabase: .private(cloudKitContainerIdentifier)' "衣橱存储/____App.swift"; then
  issue "SwiftData container is not configured for private CloudKit sync"
fi

if grep -q 'WeatherCardAttributionBadge' "衣橱存储/WeatherCardView.swift"; then
  issue "home weather card still contains the old obstructive WeatherKit attribution badge"
fi

if ! grep -q 'WeatherAttributionBlock' "衣橱存储/WeatherDetailView.swift"; then
  issue "weather detail does not show WeatherKit attribution"
fi

if ! grep -q 'Link("数据来源"' "衣橱存储/WeatherDetailView.swift"; then
  issue "weather detail does not expose WeatherKit legal attribution link"
fi

RISKY_ASSETS="$(
  find '衣橱存储/Assets.xcassets' -type f \
    | grep -E '小红书|水印|来自|download|web|网页版|unsplash|pexels|素材' \
    || true
)"

if [[ -n "$RISKY_ASSETS" ]]; then
  issue "Assets.xcassets contains filenames that need license review:"
  printf '%s\n' "$RISKY_ASSETS" >&2
fi

if [[ "$ISSUES" -eq 0 ]]; then
  printf 'App Store readiness audit passed.\n'
  exit 0
fi

printf 'App Store readiness audit found %d issue(s).\n' "$ISSUES" >&2

if [[ "$STRICT" -eq 1 ]]; then
  exit 1
fi

printf 'Run with --strict to make these issues fail CI/release checks.\n'
