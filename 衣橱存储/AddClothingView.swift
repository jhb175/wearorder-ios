import SwiftUI
import SwiftData

struct AddClothingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSaved: ((WardrobeItem) -> Void)? = nil

    @State private var draft = ClothingDraft()
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        NavigationStack {
            ClothingEditorForm(
                draft: $draft,
                showsSaveSection: true,
                saveButtonTitle: "保存衣物",
                onSave: saveClothing
            )
            .navigationTitle("添加衣物")
            .homeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("衣物保存失败", isPresented: $showsSaveError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private func saveClothing() {
        let newItem = WardrobeItem(
            name: draft.trimmedName,
            category: draft.category,
            colorName: draft.colorName,
            season: draft.season,
            imageSymbol: draft.imageSymbol,
            imageData: draft.imageData,
            styleTagsText: draft.styleTagsText,
            notes: draft.notes,
            brand: draft.brand,
            size: draft.size,
            purchasePrice: draft.normalizedPurchasePrice,
            purchaseDate: draft.hasPurchaseDate ? draft.purchaseDate : nil,
            purchaseChannel: draft.purchaseChannel,
            careNotes: draft.careNotes
        )

        modelContext.insert(newItem)
        do {
            try modelContext.save()
            AppHaptics.success()
            onSaved?(newItem)
            dismiss()
        } catch {
            modelContext.delete(newItem)
            saveErrorMessage = error.localizedDescription
            showsSaveError = true
        }
    }
}

enum WardrobeCategory: String, CaseIterable {
    case top = "上装"
    case outerwear = "外套"
    case bottom = "下装"
    case skirt = "裙装"
    case shoes = "鞋履"
    case bag = "包袋"
    case accessory = "配饰"
    case hat = "帽子"

    var defaultSymbolName: String {
        switch self {
        case .top:
            "shirt.fill"
        case .outerwear:
            "sparkles"
        case .bottom:
            "figure.walk"
        case .skirt:
            "sun.max.trianglebadge.exclamationmark"
        case .shoes:
            "shoe.2.fill"
        case .bag:
            "bag.fill"
        case .accessory:
            "circle.hexagongrid.fill"
        case .hat:
            "cap.fill"
        }
    }
}

enum ClothingSeason: String, CaseIterable {
    case all = "四季"
    case springSummer = "春夏"
    case springAutumn = "春秋"
    case autumnWinter = "秋冬"
}

struct ClothingColorSwatch: Equatable {
    let name: String
    let red: Double
    let green: Double
    let blue: Double
}

enum ClothingPalette {
    static let swatches: [ClothingColorSwatch] = [
        .init(name: "奶油白", red: 0.96, green: 0.94, blue: 0.86),
        .init(name: "暖白", red: 0.98, green: 0.96, blue: 0.92),
        .init(name: "珠光白", red: 0.94, green: 0.95, blue: 0.96),
        .init(name: "浅灰", red: 0.72, green: 0.72, blue: 0.72),
        .init(name: "炭灰", red: 0.31, green: 0.33, blue: 0.38),
        .init(name: "曜石黑", red: 0.06, green: 0.06, blue: 0.07),
        .init(name: "燕麦卡其", red: 0.76, green: 0.66, blue: 0.51),
        .init(name: "焦糖棕", red: 0.67, green: 0.45, blue: 0.28),
        .init(name: "酒红", red: 0.48, green: 0.08, blue: 0.12),
        .init(name: "玫瑰粉", red: 0.88, green: 0.56, blue: 0.65),
        .init(name: "雾蓝", red: 0.44, green: 0.58, blue: 0.77),
        .init(name: "海军蓝", red: 0.08, green: 0.17, blue: 0.34),
        .init(name: "鼠尾草绿", red: 0.49, green: 0.62, blue: 0.50),
        .init(name: "森林绿", red: 0.12, green: 0.32, blue: 0.22),
        .init(name: "丁香紫", red: 0.57, green: 0.47, blue: 0.70)
    ]

    static let presets = swatches.map(\.name)

    static func color(for name: String) -> Color {
        guard let swatch = swatch(for: name) else { return .accentColor }
        return Color(red: swatch.red, green: swatch.green, blue: swatch.blue)
    }

    static func swatch(for name: String) -> ClothingColorSwatch? {
        swatches.first { $0.name == name }
    }
}

extension String {
    var defaultSymbolName: String {
        WardrobeCategory(rawValue: self)?.defaultSymbolName ?? "sparkles"
    }
}

#Preview("Add Clothing") {
    AddClothingView()
        .modelContainer(WardrobePreviewContainer.shared)
}
