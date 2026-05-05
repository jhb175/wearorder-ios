import Foundation

/// Top-level entry point for outfit generation. Despite the legacy name,
/// this class is now a *router* — it picks the cheapest correct provider
/// for the current device + config and forwards. UI calls `generate(...)`
/// on this and gets back a `GenerationResult` regardless of whether the
/// model lives on the user's phone or behind our backend.
///
/// Routing rules (highest-priority first):
///   1. Apple Intelligence is `available` → on-device provider
///   2. `BackendOutfitConfig.isConfigured` → cloud provider
///   3. Neither → throw `.unavailable`
@MainActor
final class AIOutfitGenerator {

    enum GenerationError: Error, LocalizedError {
        case unavailable(reason: String)
        case modelError(message: String)
        case invalidOutput(underlying: Error)
        case offTopic(message: String)
        case rateLimited(message: String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason):
                return reason
            case .modelError(let message):
                return message
            case .invalidOutput(let underlying):
                return (underlying as? LocalizedError)?.errorDescription
                    ?? "AI 返回的搭配无法解析。"
            case .offTopic(let message):
                return message
            case .rateLimited(let message):
                return message
            }
        }
    }

    struct GenerationResult: Equatable {
        let resolved: AIOutfitValidator.Resolved
        let context: AIWardrobeContext
        let modelIdentifier: String
        let weatherSummary: String
        let promptUsed: String
    }

    static let onDeviceModelIdentifier = "apple-foundation-on-device"

    /// Generate one full outfit suggestion. Resolves the best-available
    /// provider per the routing rules above.
    func generate(
        userPrompt: String,
        weather: HomeDashboardViewModel.WeatherSnapshot?,
        items: [WardrobeItem]
    ) async throws -> GenerationResult {

        let context = AIWardrobeContextBuilder.build(
            userPrompt: userPrompt,
            weather: weather,
            items: items
        )

        guard !context.candidatesBySlot.values.allSatisfy({ $0.isEmpty }) else {
            throw GenerationError.unavailable(
                reason: "衣橱里还没有可以搭配的单品，先去添加几件衣物再试。"
            )
        }

        let provider = try resolveProvider()
        return try await provider.generate(context: context)
    }

    // MARK: - Provider resolution

    /// Picks the highest-priority provider available right now. The
    /// runtime checks happen on every call so toggling Apple
    /// Intelligence in Settings, or a backend going from unconfigured
    /// to configured, takes effect immediately without restarting.
    private func resolveProvider() throws -> AIOutfitProviding {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = AIAvailability.current {
            return OnDeviceOutfitProvider()
        }
        #endif

        if BackendOutfitConfig.isConfigured {
            return CloudOutfitProvider()
        }

        // Surface the most actionable hint we can.
        let baseMessage = AIAvailability.disabledMessage
        if !baseMessage.isEmpty {
            throw GenerationError.unavailable(reason: baseMessage)
        }
        throw GenerationError.unavailable(
            reason: "AI 搭配师当前不可用，请稍后再试。"
        )
    }
}
