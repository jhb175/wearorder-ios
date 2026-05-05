import Foundation
#if canImport(FoundationModels)
import FoundationModels

/// Structured output schema for outfit generation.
///
/// Constrained decoding guarantees the model emits exactly these
/// fields with the right types — but it does NOT enforce that the IDs
/// are real wardrobe IDs or that categories match slots. That's
/// `AIOutfitValidator`'s job.
@available(iOS 26.0, *)
@Generable
struct AIGeneratedOutfit: Equatable, Sendable {
    @Guide(description: "搭配标题，6-12 个汉字，体现风格或场合，例如：通勤简洁套装、咖啡馆休闲风。")
    var title: String

    @Guide(description: "为什么这样搭配的原因，30-60 个汉字，结合天气、场合、单品特征。")
    var reason: String

    @Guide(description: "上装单品 ID。除非衣橱里完全没有上装可选，否则必须填一件。")
    var topItemID: String?

    @Guide(description: "下装单品 ID。除非已选连衣裙类的上装，否则必须填一件。")
    var bottomItemID: String?

    @Guide(description: "外套单品 ID。冷天、空调环境、要叠穿层次时填；温暖室内可不填。")
    var outerwearItemID: String?

    @Guide(description: "鞋子单品 ID。可选；按场合和走路距离决定。")
    var shoesItemID: String?

    @Guide(description: "包袋单品 ID。可选；通勤、外出场景填。")
    var bagItemID: String?

    @Guide(description: "配饰单品 ID。可选；点睛或御寒（围巾/帽子）。")
    var accessoryItemID: String?
}

/// Slot identifier reused for partial regeneration in Sprint 3.2.
@available(iOS 26.0, *)
enum AIOutfitSlot: String, CaseIterable, Sendable {
    case top, bottom, outerwear, shoes, bag, accessory

    var displayTitle: String {
        switch self {
        case .top: return "上装"
        case .bottom: return "下装"
        case .outerwear: return "外套"
        case .shoes: return "鞋"
        case .bag: return "包"
        case .accessory: return "配饰"
        }
    }
}

@available(iOS 26.0, *)
extension AIGeneratedOutfit {
    /// Returns the ID emitted for the requested slot, or `nil` if the
    /// model didn't fill that slot.
    func itemID(for slot: AIOutfitSlot) -> String? {
        switch slot {
        case .top: return topItemID
        case .bottom: return bottomItemID
        case .outerwear: return outerwearItemID
        case .shoes: return shoesItemID
        case .bag: return bagItemID
        case .accessory: return accessoryItemID
        }
    }
}

#endif
