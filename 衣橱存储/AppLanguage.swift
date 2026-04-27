import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans-CN"
    case english = "en"
    case korean = "ko"
    case japanese = "ja"

    static let storageKey = "wearorderAppLanguage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese:
            "中文"
        case .english:
            "English"
        case .korean:
            "한국어"
        case .japanese:
            "日本語"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func value(for rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .chinese
    }
}
