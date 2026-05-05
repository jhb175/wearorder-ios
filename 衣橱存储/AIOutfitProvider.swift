import Foundation

/// Protocol abstraction over "give me a generated outfit" so the UI
/// doesn't care whether the answer came from Apple's on-device model
/// or from our backend proxy.
///
/// Both providers consume the **same** `AIWardrobeContext` and produce
/// the **same** `AIOutfitGenerator.GenerationResult`. Anything that
/// would diverge (model identifier, network errors, validation
/// failures) is folded into `GenerationError`.
@MainActor
protocol AIOutfitProviding: Sendable {

    /// Stable identifier for telemetry and logs. Examples:
    /// `apple-foundation-on-device`, `cloud:DeepSeek/deepseek-chat`.
    var modelIdentifier: String { get }

    /// Run a single generation. Throws `AIOutfitGenerator.GenerationError`
    /// so the call site can map cleanly to the existing UI states.
    func generate(context: AIWardrobeContext) async throws -> AIOutfitGenerator.GenerationResult
}
