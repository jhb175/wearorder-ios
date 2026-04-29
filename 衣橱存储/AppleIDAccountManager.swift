import AuthenticationServices
import Combine
import Foundation
import Security

struct AppleIDAccountSession: Codable, Equatable {
    var userID: String
    var email: String?
    var fullName: String?
    var lastSignInAt: Date

    var displayName: String {
        if let fullName, !fullName.isEmpty {
            return fullName
        }

        if let email, !email.isEmpty {
            return email
        }

        return "Apple ID 用户"
    }

    var detailText: String {
        if let email, !email.isEmpty {
            return email
        }

        return maskedUserID
    }

    var maskedUserID: String {
        guard userID.count > 8 else {
            return userID
        }

        return "•••• " + userID.suffix(6)
    }
}

enum AppleIDCredentialStatus: Equatable {
    case signedOut
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown(String?)

    var title: String {
        switch self {
        case .signedOut:
            return "未登录"
        case .authorized:
            return "已授权"
        case .revoked:
            return "授权已撤销"
        case .notFound:
            return "账号凭证不存在"
        case .transferred:
            return "账号已迁移"
        case .unknown:
            return "状态待确认"
        }
    }

    var subtitle: String {
        switch self {
        case .signedOut:
            return "登录后可用于后续会员、AI 和跨设备账号识别"
        case .authorized:
            return "Apple 已确认当前登录凭证有效"
        case .revoked:
            return "请重新使用 Apple ID 登录"
        case .notFound:
            return "本机保存的 Apple ID 凭证已失效"
        case .transferred:
            return "该账号状态已迁移，建议重新登录"
        case .unknown(let message):
            return message ?? "暂时无法确认凭证状态，请稍后重试"
        }
    }
}

enum AppleIDSignInOutcome: Equatable {
    case success(AppleIDAccountSession)
    case failure(String)
}

@MainActor
final class AppleIDAccountManager: ObservableObject {
    @Published private(set) var session: AppleIDAccountSession?
    @Published private(set) var credentialStatus: AppleIDCredentialStatus

    init() {
        let storedSession = AppleIDAccountKeychainStore.load()
        session = storedSession
        credentialStatus = storedSession == nil ? .signedOut : .unknown(nil)
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func completeSignIn(with result: Result<ASAuthorization, Error>) -> AppleIDSignInOutcome {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return .failure("没有取得有效的 Apple ID 凭证，请重试。")
            }

            let existingSession = session?.userID == credential.user ? session : nil
            let updatedSession = AppleIDAccountSession(
                userID: credential.user,
                email: credential.email ?? existingSession?.email,
                fullName: Self.formattedName(from: credential.fullName) ?? existingSession?.fullName,
                lastSignInAt: Date()
            )

            do {
                try AppleIDAccountKeychainStore.save(updatedSession)
                session = updatedSession
                credentialStatus = .authorized
                return .success(updatedSession)
            } catch {
                return .failure("Apple ID 登录成功，但保存本机账号状态失败：\(error.localizedDescription)")
            }

        case .failure(let error):
            return .failure(Self.authorizationErrorMessage(for: error))
        }
    }

    func refreshCredentialState() async {
        guard let userID = session?.userID else {
            credentialStatus = .signedOut
            return
        }

        let result = await Self.credentialState(for: userID)

        switch result {
        case .success(.authorized):
            credentialStatus = .authorized
        case .success(.revoked):
            AppleIDAccountKeychainStore.delete()
            session = nil
            credentialStatus = .revoked
        case .success(.notFound):
            AppleIDAccountKeychainStore.delete()
            session = nil
            credentialStatus = .notFound
        case .success(.transferred):
            credentialStatus = .transferred
        case .success:
            credentialStatus = .unknown(nil)
        case .failure(let error):
            credentialStatus = .unknown(error.localizedDescription)
        }
    }

    func signOutLocal() {
        AppleIDAccountKeychainStore.delete()
        session = nil
        credentialStatus = .signedOut
    }

    private static func credentialState(
        for userID: String
    ) async -> Result<ASAuthorizationAppleIDProvider.CredentialState, Error> {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(state))
                }
            }
        }
    }

    private static func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else {
            return nil
        }

        let formatter = PersonNameComponentsFormatter()
        formatter.style = .medium
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func authorizationErrorMessage(for error: Error) -> String {
        guard let authorizationError = error as? ASAuthorizationError else {
            return error.localizedDescription
        }

        switch authorizationError.code {
        case .canceled:
            return "已取消 Apple ID 登录。"
        case .failed:
            return "Apple ID 登录失败，请检查网络或稍后重试。"
        case .invalidResponse:
            return "Apple ID 返回了无效响应，请重试。"
        case .notHandled:
            return "Apple ID 登录请求没有完成，请重试。"
        case .unknown:
            return "Apple ID 登录发生未知错误。"
        case .preferSignInWithApple:
            return "建议使用 Apple ID 完成登录。"
        case .notInteractive:
            return "当前环境不能显示 Apple ID 登录界面。"
        case .deviceNotConfiguredForPasskeyCreation:
            return "当前设备未配置通行密钥，请完成系统设置后重试。"
        case .matchedExcludedCredential:
            return "当前凭证不适合此登录请求，请换一个 Apple ID 重试。"
        case .credentialImport:
            return "Apple ID 凭证导入失败，请重试。"
        case .credentialExport:
            return "Apple ID 凭证导出失败，请重试。"
        @unknown default:
            return "Apple ID 登录失败，请稍后重试。"
        }
    }
}

private enum AppleIDAccountKeychainStore {
    private static let service = "com.ramsey.wearorder.apple-id-account"
    private static let account = "primary"

    static func load() -> AppleIDAccountSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(AppleIDAccountSession.self, from: data)
    }

    static func save(_ session: AppleIDAccountSession) throws {
        let data = try JSONEncoder().encode(session)
        var query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private struct KeychainError: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }

            return "Keychain error \(status)"
        }
    }
}
