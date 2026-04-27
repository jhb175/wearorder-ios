import Foundation

enum AppReleaseInfo {
    static let appName = "衣序"
    static let englishAppName = "WearOrder"

    // Public release contacts mirrored in APP_STORE_METADATA.md and the legal pages.
    static let privacyPolicyURLString = "https://jhb175.github.io/wearorder-legal/privacy-policy.html"
    static let supportURLString = "https://jhb175.github.io/wearorder-legal/support.html"
    static let supportEmail = "1434143178@231316546.xyz"

    static var allowsSampleDataEntry: Bool {
        #if INTERNAL_TOOLS
        true
        #else
        false
        #endif
    }

    static var privacyPolicyURL: URL? {
        makePublicHTTPSURL(privacyPolicyURLString)
    }

    static var supportURL: URL? {
        makePublicHTTPSURL(supportURLString)
    }

    static var supportMailURL: URL? {
        let trimmedEmail = supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidSupportEmail(trimmedEmail) else { return nil }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = trimmedEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "\(appName) 用户支持")
        ]
        return components.url
    }

    static var isPublicReleaseContactConfigured: Bool {
        privacyPolicyURL != nil && supportURL != nil && isValidSupportEmail(supportEmail)
    }

    static var releaseContactStatusTitle: String {
        isPublicReleaseContactConfigured ? "隐私与支持已配置" : "隐私与支持待配置"
    }

    static var releaseContactStatusMessage: String {
        if isPublicReleaseContactConfigured {
            return "隐私政策、支持页面和支持邮箱已可用。"
        }
        return missingReleaseContactItems.joined(separator: "、")
    }

    static var missingReleaseContactItems: [String] {
        var items: [String] = []

        if privacyPolicyURL == nil {
            items.append("隐私政策 HTTPS URL")
        }

        if supportURL == nil {
            items.append("支持页面 HTTPS URL")
        }

        if !isValidSupportEmail(supportEmail) {
            items.append("支持邮箱")
        }

        return items
    }

    static func makePublicHTTPSURL(_ value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedValue),
            url.scheme?.lowercased() == "https",
            let host = url.host(percentEncoded: false),
            host.contains(".")
        else {
            return nil
        }
        return url
    }

    static func isValidSupportEmail(_ value: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.contains(" ") else { return false }

        let parts = trimmedValue.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, let domain = parts.last else { return false }
        return !parts[0].isEmpty && domain.contains(".") && !domain.hasSuffix(".")
    }
}
