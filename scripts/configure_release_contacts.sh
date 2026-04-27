#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/configure_release_contacts.sh \
    --privacy-url https://example.org/privacy \
    --support-url https://example.org/support \
    --support-email support@example.org

Options:
  --dry-run       Validate inputs and required files without editing.
  --help          Show this help text.
USAGE
}

DRY_RUN=0
PRIVACY_URL=""
SUPPORT_URL=""
SUPPORT_EMAIL=""

fail() {
  printf 'Release contact configuration failed: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --privacy-url)
      [[ $# -ge 2 ]] || fail "--privacy-url requires a value"
      PRIVACY_URL="$2"
      shift 2
      ;;
    --support-url)
      [[ $# -ge 2 ]] || fail "--support-url requires a value"
      SUPPORT_URL="$2"
      shift 2
      ;;
    --support-email)
      [[ $# -ge 2 ]] || fail "--support-email requires a value"
      SUPPORT_EMAIL="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

validate_public_https_url() {
  local label="$1"
  local value="$2"

  [[ "$value" =~ ^https://[^[:space:]]+\.[^[:space:]]+ ]] \
    || fail "$label must be a public HTTPS URL"

  if [[ "$value" =~ localhost|127\.0\.0\.1|0\.0\.0\.0|example\.com|example\.org|example\.net ]]; then
    fail "$label must not use localhost or example domains"
  fi
}

validate_email() {
  local value="$1"

  [[ "$value" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] \
    || fail "support email must be a valid email address"

  if [[ "$value" =~ example\.com|example\.org|example\.net ]]; then
    fail "support email must not use example domains"
  fi
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

[[ -n "$PRIVACY_URL" ]] || fail "--privacy-url is required"
[[ -n "$SUPPORT_URL" ]] || fail "--support-url is required"
[[ -n "$SUPPORT_EMAIL" ]] || fail "--support-email is required"

validate_public_https_url "privacy URL" "$PRIVACY_URL"
validate_public_https_url "support URL" "$SUPPORT_URL"
validate_email "$SUPPORT_EMAIL"

require_file "APP_STORE_METADATA.md"
require_file "docs/privacy-policy.html"
require_file "docs/support.html"
require_file "衣橱存储/AppReleaseInfo.swift"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Release contact inputs are valid. No files changed.\n'
  exit 0
fi

export PRIVACY_URL
export SUPPORT_URL
export SUPPORT_EMAIL

perl -0pi -e '
  s/static let privacyPolicyURLString = ".*?"/static let privacyPolicyURLString = "$ENV{PRIVACY_URL}"/;
  s/static let supportURLString = ".*?"/static let supportURLString = "$ENV{SUPPORT_URL}"/;
  s/static let supportEmail = ".*?"/static let supportEmail = "$ENV{SUPPORT_EMAIL}"/;
' "衣橱存储/AppReleaseInfo.swift"

perl -0pi -e '
  s/上架状态：.*\n/上架状态：待最终人工 QA，公开 Privacy Policy URL、Support URL 和真实支持邮箱已配置。\n/;
  s|Privacy Policy URL：.*|Privacy Policy URL：$ENV{PRIVACY_URL}|;
  s|Support URL：.*|Support URL：$ENV{SUPPORT_URL}|;
  s|联系邮箱：.*|联系邮箱：$ENV{SUPPORT_EMAIL}|;
  s|将 Privacy Policy URL 替换为真实公网链接。|Privacy Policy URL 已配置：$ENV{PRIVACY_URL}。|;
  s|将 Support URL 替换为真实公网链接。|Support URL 已配置：$ENV{SUPPORT_URL}。|;
  s|将联系邮箱替换为开发者实际可收信邮箱。|联系邮箱已配置：$ENV{SUPPORT_EMAIL}。|;
' "APP_STORE_METADATA.md"

perl -0pi -e '
  s|请将此处替换为开发者支持邮箱。上架前需要确保该邮箱真实可用。|如需隐私相关支持，请发送邮件至 <a href="mailto:$ENV{SUPPORT_EMAIL}">$ENV{SUPPORT_EMAIL}</a>。|;
  s|如需隐私相关支持，请发送邮件至 <a href="mailto:[^"]+">[^<]+</a>。|如需隐私相关支持，请发送邮件至 <a href="mailto:$ENV{SUPPORT_EMAIL}">$ENV{SUPPORT_EMAIL}</a>。|;
' "docs/privacy-policy.html"

perl -0pi -e '
  s|这里是衣序的用户支持页面。上架前请把本页部署为公开 HTTPS 链接，并替换为真实开发者联系方式。|这里是衣序的用户支持页面。你可以在这里查看常见问题，并通过支持邮箱联系我们。|;
  s|支持邮箱：请在上架前替换为真实邮箱。|支持邮箱：<a href="mailto:$ENV{SUPPORT_EMAIL}">$ENV{SUPPORT_EMAIL}</a>|;
  s|支持邮箱：<a href="mailto:[^"]+">[^<]+</a>|支持邮箱：<a href="mailto:$ENV{SUPPORT_EMAIL}">$ENV{SUPPORT_EMAIL}</a>|;
' "docs/support.html"

printf 'Release contact configuration updated.\n'
printf 'Privacy Policy URL: %s\n' "$PRIVACY_URL"
printf 'Support URL: %s\n' "$SUPPORT_URL"
printf 'Support email: %s\n' "$SUPPORT_EMAIL"
printf 'Next: deploy docs/privacy-policy.html and docs/support.html to those public HTTPS URLs, then run ./scripts/audit_app_store_readiness.sh --strict.\n'
