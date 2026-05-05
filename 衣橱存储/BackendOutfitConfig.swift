import Foundation

/// Build-time + runtime configuration for the backend outfit endpoint.
///
/// Resolution order:
///   1. Info.plist key `WEARORDER_AI_BASE_URL` — set per-build via xcconfig
///      so debug points at localhost and release points at production
///   2. UserDefaults key `WearOrderAIBaseURL` — runtime override (debug
///      builds expose this in a settings screen for testing)
///
/// Whether the cloud route is available is just "is one of those set
/// to a valid HTTPS URL". No URL = on-device only mode.
enum BackendOutfitConfig {

    private static let infoPlistKey = "WEARORDER_AI_BASE_URL"
    private static let userDefaultsKey = "WearOrderAIBaseURL"
    private static let deviceIDKey = "WearOrderDeviceID"

    /// Resolved base URL. Returns nil when no backend is configured —
    /// AI router falls back to on-device only.
    static var baseURL: URL? {
        if let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
           let url = sanitize(raw) {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           let url = sanitize(raw) {
            return url
        }
        return nil
    }

    /// Whether enough config is present to attempt a cloud call.
    static var isConfigured: Bool { baseURL != nil }

    /// Stable per-installation device identifier sent in `X-Device-ID`.
    /// Persisted in UserDefaults — survives app restarts but not full
    /// app deletion. That's fine: deletion = new user from our POV,
    /// rate-limit reset is a feature.
    static var deviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: deviceIDKey)
        return fresh
    }

    /// Override for debugging. Pass nil to clear.
    static func setRuntimeBaseURLOverride(_ raw: String?) {
        let defaults = UserDefaults.standard
        guard let raw, !raw.isEmpty else {
            defaults.removeObject(forKey: userDefaultsKey)
            return
        }
        defaults.set(raw, forKey: userDefaultsKey)
    }

    private static func sanitize(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }
}
