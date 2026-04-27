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

if ! grep -q 'NSPrivacyCollectedDataTypePreciseLocation' "衣橱存储/PrivacyInfo.xcprivacy"; then
  issue "PrivacyInfo.xcprivacy does not declare precise location collection for weather"
fi

if ! grep -q 'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription' "衣橱存储.xcodeproj/project.pbxproj"; then
  issue "project does not contain NSLocationWhenInUseUsageDescription for weather"
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
