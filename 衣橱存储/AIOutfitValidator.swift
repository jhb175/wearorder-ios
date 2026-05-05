import Foundation

/// Validates raw `AIGeneratedOutfit` output against the candidate
/// pool. Constrained decoding stops the model from emitting wrong
/// types, but it cannot prevent two real failure modes:
///
/// 1. **Hallucinated IDs** — model invents a UUID that isn't in the
///    pool. Reject so the UI can retry.
/// 2. **Slot/category mismatch** — model puts a real shoe ID into
///    `topItemID`. Reject for the same reason.
///
/// On success we resolve each ID to a `WardrobeItem` reference, ready
/// to drop into `OOTDOutfit` via the existing save flow.
enum AIOutfitValidator {

    enum ValidationError: Error, Equatable, LocalizedError {
        case missingRequiredSlot(slotKey: String)
        case unknownItemID(slotKey: String, idString: String)
        case slotCategoryMismatch(slotKey: String, idString: String)

        var errorDescription: String? {
            switch self {
            case .missingRequiredSlot(let slot):
                return "AI 没有选择 \(slot) 单品。"
            case .unknownItemID(let slot, _):
                return "AI 在 \(slot) 槽位返回了一个不存在的单品。"
            case .slotCategoryMismatch(let slot, _):
                return "AI 把一件不属于 \(slot) 的单品放到了这个位置。"
            }
        }
    }

    struct Resolved: Equatable {
        let title: String
        let reason: String
        let items: [String: WardrobeItem]  // slotKey -> item

        var topItem: WardrobeItem? { items["top"] }
        var bottomItem: WardrobeItem? { items["bottom"] }
        var outerwearItem: WardrobeItem? { items["outerwear"] }
        var shoesItem: WardrobeItem? { items["shoes"] }
        var bagItem: WardrobeItem? { items["bag"] }
        var accessoryItem: WardrobeItem? { items["accessory"] }
    }

    /// Validate a `GeneratedOutfit`-shaped payload.
    ///
    /// We don't take `AIGeneratedOutfit` directly so that this file
    /// stays compilable on every iOS version (the @Generable type is
    /// iOS 26+). Caller passes plain string IDs and gets back a
    /// resolved set or a typed error.
    static func validate(
        title: String,
        reason: String,
        slotIDs: [String: String?],
        context: AIWardrobeContext
    ) throws -> Resolved {
        var resolved: [String: WardrobeItem] = [:]

        for slotKey in AIWardrobeContext.slotKeys {
            guard let optionalID = slotIDs[slotKey], let idString = optionalID, !idString.isEmpty else {
                continue  // optional slot, skip
            }
            guard let item = context.item(matching: idString) else {
                throw ValidationError.unknownItemID(slotKey: slotKey, idString: idString)
            }
            guard context.isCandidate(item, forSlotKey: slotKey) else {
                throw ValidationError.slotCategoryMismatch(slotKey: slotKey, idString: idString)
            }
            resolved[slotKey] = item
        }

        // We require at least a top OR a bottom — otherwise the
        // "outfit" is just a hat or a pair of shoes, not useful.
        if resolved["top"] == nil && resolved["bottom"] == nil {
            throw ValidationError.missingRequiredSlot(slotKey: "top 或 bottom")
        }

        return Resolved(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            items: resolved
        )
    }
}
