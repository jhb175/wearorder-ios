import Foundation

enum WardrobeOnboardingState {
    static let storageKey = "onboarding.hasSeenV1"

    static func shouldPresent(
        hasSeenOnboarding: Bool,
        isPreview: Bool,
        isEmptyWardrobe: Bool
    ) -> Bool {
        !hasSeenOnboarding && !isPreview && isEmptyWardrobe
    }
}

enum WardrobeOnboardingAction {
    case addClothing
    case loadSampleData
    case openSettings
    case dismiss
}
