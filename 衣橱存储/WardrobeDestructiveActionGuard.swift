import Foundation

enum WardrobeDestructiveActionGuard {
    static let resetConfirmationPhrase = "清空"

    static func canConfirmReset(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == resetConfirmationPhrase
    }
}
