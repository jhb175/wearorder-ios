import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class AIOutfitGenerator {

    enum GenerationError: Error, LocalizedError {
        case unavailable(reason: String)
        case modelError(message: String)
        case invalidOutput(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason):
                return reason
            case .modelError(let message):
                return message
            case .invalidOutput(let underlying):
                return (underlying as? LocalizedError)?.errorDescription
                    ?? "AI 返回的搭配无法解析。"
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

    private static let instructions = """
    你是衣序 App 的 AI 搭配师。从用户提供的"可选单品"列表里挑选一套日常搭配，
    输出标题、理由，以及 6 个槽位（top/bottom/outerwear/shoes/bag/accessory）的单品 ID。
    必须严格遵守以下规则：

    1. 每个 *ItemID 字段，只能使用列表里出现过的 ID。绝不发明 ID。
    2. ID 一定要从"# 上装/下装/..."对应的小节里挑，不要把鞋的 ID 放进上装。
    3. 如果某个槽位没有合适的，把对应字段留空（null）。
    4. 上装、下装尽量都填；连衣裙类作为上装时下装可以空。
    5. 标题 6-12 个汉字；理由 30-60 个汉字，结合天气和场景给出穿搭建议。
    """

    /// Generate one full outfit suggestion.
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

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await generateWithSystemModel(context: context)
        } else {
            throw GenerationError.unavailable(reason: "AI 搭配师需要 iOS 26 及以上版本。")
        }
        #else
        throw GenerationError.unavailable(reason: "当前 SDK 不支持 AI 搭配师。")
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithSystemModel(
        context: AIWardrobeContext
    ) async throws -> GenerationResult {

        guard case .available = AIAvailability.current else {
            throw GenerationError.unavailable(reason: AIAvailability.disabledMessage)
        }

        let session = LanguageModelSession(instructions: Self.instructions)

        do {
            let response = try await session.respond(
                to: context.promptText,
                generating: AIGeneratedOutfit.self
            )
            let generated = response.content

            let slotIDs: [String: String?] = [
                "top": generated.topItemID,
                "bottom": generated.bottomItemID,
                "outerwear": generated.outerwearItemID,
                "shoes": generated.shoesItemID,
                "bag": generated.bagItemID,
                "accessory": generated.accessoryItemID
            ]

            do {
                let resolved = try AIOutfitValidator.validate(
                    title: generated.title,
                    reason: generated.reason,
                    slotIDs: slotIDs,
                    context: context
                )
                return GenerationResult(
                    resolved: resolved,
                    context: context,
                    modelIdentifier: Self.onDeviceModelIdentifier,
                    weatherSummary: context.weatherSummary,
                    promptUsed: context.userPrompt
                )
            } catch {
                throw GenerationError.invalidOutput(underlying: error)
            }
        } catch let error as GenerationError {
            throw error
        } catch {
            throw GenerationError.modelError(
                message: "AI 当前不可用：\(error.localizedDescription)"
            )
        }
    }
    #endif
}
