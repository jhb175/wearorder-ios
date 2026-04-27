import SwiftData
import SwiftUI

struct CreateOOTDView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]

    @State private var title = "新搭配"
    @State private var notes = ""
    @State private var selectedTopID: PersistentIdentifier?
    @State private var selectedBottomID: PersistentIdentifier?
    @State private var selectedOuterwearID: PersistentIdentifier?
    @State private var selectedShoesID: PersistentIdentifier?
    @State private var selectedBagID: PersistentIdentifier?
    @State private var selectedAccessoryID: PersistentIdentifier?
    @State private var marksAsToday = true
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""
    private let editingOutfit: OOTDOutfit?
    private let prefilledItemID: PersistentIdentifier?
    private let prefilledSlotTitle: String?
    private let onSaved: ((OOTDOutfit) -> Void)?

    init(
        draft: OOTDCreationDraft? = nil,
        prefilledItem: WardrobeItem? = nil,
        onSaved: ((OOTDOutfit) -> Void)? = nil
    ) {
        let itemID = prefilledItem?.persistentModelID
        editingOutfit = nil
        _title = State(initialValue: draft?.title ?? "新搭配")
        _notes = State(initialValue: draft?.notes ?? "")
        _selectedTopID = State(initialValue: CreateOOTDView.initialSelection(for: prefilledItem, slot: .top))
        _selectedBottomID = State(initialValue: CreateOOTDView.initialSelection(for: prefilledItem, slot: .bottom))
        _selectedOuterwearID = State(initialValue: CreateOOTDView.initialSelection(for: prefilledItem, slot: .outerwear))
        _selectedShoesID = State(initialValue: CreateOOTDView.initialSelection(for: prefilledItem, slot: .shoes))
        _selectedBagID = State(initialValue: CreateOOTDView.initialSelection(for: prefilledItem, slot: .bag))
        _selectedAccessoryID = State(initialValue: CreateOOTDView.initialSelection(for: prefilledItem, slot: .accessory))
        _marksAsToday = State(initialValue: draft?.marksAsToday ?? true)
        prefilledItemID = itemID
        prefilledSlotTitle = prefilledItem.flatMap { CreateOOTDView.prefilledSlotTitle(for: $0) }
        self.onSaved = onSaved
    }

    init(editingOutfit: OOTDOutfit, onSaved: ((OOTDOutfit) -> Void)? = nil) {
        self.editingOutfit = editingOutfit
        _title = State(initialValue: editingOutfit.title)
        _notes = State(initialValue: editingOutfit.notes)
        _selectedTopID = State(initialValue: editingOutfit.topItem?.persistentModelID)
        _selectedBottomID = State(initialValue: editingOutfit.bottomItem?.persistentModelID)
        _selectedOuterwearID = State(initialValue: editingOutfit.outerwearItem?.persistentModelID)
        _selectedShoesID = State(initialValue: editingOutfit.shoesItem?.persistentModelID)
        _selectedBagID = State(initialValue: editingOutfit.bagItem?.persistentModelID)
        _selectedAccessoryID = State(initialValue: editingOutfit.accessoryItem?.persistentModelID)
        _marksAsToday = State(initialValue: editingOutfit.isToday)
        prefilledItemID = nil
        prefilledSlotTitle = nil
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(editingOutfit == nil ? "新建 OOTD" : "编辑 OOTD")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(editingOutfit == nil ? "从现有衣橱里挑选单品，先完成手动搭配闭环。" : "调整标题、备注和单品组合，保存后会同步到首页和计划。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        summaryChip(title: "可选单品", value: "\(items.count)")
                        summaryChip(title: "已存搭配", value: "\(outfits.count)")
                        summaryChip(title: "今日搭配", value: marksAsToday ? "将更新" : "不设置")
                    }
                }

                if let prefilledItem = selectedItem(for: prefilledItemID), let prefilledSlotTitle {
                    prefilledItemBanner(item: prefilledItem, slotTitle: prefilledSlotTitle)
                }

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(title: "搭配信息", subtitle: "名称与说明")
                    ootdTextField(title: "搭配名称", text: $title, prompt: "例如：今日通勤搭配")
                    ootdTextField(title: "备注", text: $notes, prompt: "例如：中性色、适合办公室")
                }

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(title: "选择单品", subtitle: "按部位组合")

                    if !coreFlowReadiness.canCreateOOTD {
                        ootdRequirementBanner
                    }

                    ootdSelectorRow(
                        title: "上装",
                        subtitle: "上装",
                        items: ootdItems(for: .top),
                        selectedID: $selectedTopID
                    )
                    ootdSelectorRow(
                        title: "下装",
                        subtitle: "下装 / 裙装",
                        items: ootdItems(for: .bottom),
                        selectedID: $selectedBottomID
                    )
                    ootdSelectorRow(
                        title: "外套",
                        subtitle: "可选",
                        items: ootdItems(for: .outerwear),
                        selectedID: $selectedOuterwearID
                    )
                    ootdSelectorRow(
                        title: "鞋子",
                        subtitle: "可选",
                        items: ootdItems(for: .shoes),
                        selectedID: $selectedShoesID
                    )
                    ootdSelectorRow(
                        title: "包",
                        subtitle: "可选",
                        items: ootdItems(for: .bag),
                        selectedID: $selectedBagID
                    )
                    ootdSelectorRow(
                        title: "配饰",
                        subtitle: "可选",
                        items: ootdItems(for: .accessory),
                        selectedID: $selectedAccessoryID
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(title: "搭配预览", subtitle: currentPreviewItems.isEmpty ? "请至少选择 2 件" : "\(currentPreviewItems.count) 件")

                    Toggle(isOn: $marksAsToday) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("保存为今日搭配")
                                .font(.subheadline.weight(.semibold))
                            Text("首页“今日 OOTD”会读取这套搭配。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if currentPreviewItems.isEmpty {
                        Text("选择上装、下装以及可选单品后，这里会显示搭配摘要。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(currentSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(currentPreviewItems, id: \.id) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: item.imageSymbol)
                                            .font(.caption.weight(.medium))
                                        Text(item.name)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(createBackground)
        .navigationTitle(editingOutfit == nil ? "新建 OOTD" : "编辑 OOTD")
        .homeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(editingOutfit == nil ? "保存" : "更新") {
                    saveOOTD()
                }
                .disabled(!canSave)
            }
        }
        .alert("OOTD 保存失败", isPresented: $showsSaveError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var createBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 0.99),
                Color(red: 0.93, green: 0.95, blue: 0.98),
                Color(red: 0.96, green: 0.95, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var trimmedTitle: String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "未命名搭配" : value
    }

    private var currentPreviewItems: [WardrobeItem] {
        [
            selectedItem(for: selectedTopID),
            selectedItem(for: selectedBottomID),
            selectedItem(for: selectedOuterwearID),
            selectedItem(for: selectedShoesID),
            selectedItem(for: selectedBagID),
            selectedItem(for: selectedAccessoryID)
        ].compactMap { $0 }
    }

    private var currentSummary: String {
        let names = currentPreviewItems.map(\.name)
        return names.isEmpty ? "尚未选择单品" : names.joined(separator: " + ")
    }

    private var canSave: Bool {
        selectedItem(for: selectedTopID) != nil && selectedItem(for: selectedBottomID) != nil
    }

    private var coreFlowReadiness: WardrobeCoreFlowReadiness {
        WardrobeCoreFlowReadiness.make(items: items, outfits: outfits)
    }

    private var ootdRequirementBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.82))

            VStack(alignment: .leading, spacing: 5) {
                Text("保存 OOTD 前需要补齐基础单品")
                    .font(.subheadline.weight(.semibold))
                Text(coreFlowReadiness.missingOOTDRequirementText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
    }

    private func prefilledItemBanner(item: WardrobeItem, slotTitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tshirt")
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.82))

            VStack(alignment: .leading, spacing: 5) {
                Text("已带入当前衣物")
                    .font(.subheadline.weight(.semibold))
                Text("“\(item.name)”已自动放入\(slotTitle)位置，你可以继续补齐其他单品。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
    }

    private func ootdItems(for slot: OOTDSlot) -> [WardrobeItem] {
        items.filter { slot.matches($0) }
    }

    private func selectedItem(for id: PersistentIdentifier?) -> WardrobeItem? {
        guard let id else { return nil }
        return items.first { $0.persistentModelID == id }
    }

    private func saveOOTD() {
        guard canSave else { return }

        if marksAsToday {
            for outfit in outfits where outfit.isToday {
                outfit.isToday = false
                outfit.updatedAt = .now
            }
        }

        let outfit: OOTDOutfit
        if let editingOutfit {
            editingOutfit.title = trimmedTitle
            editingOutfit.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            editingOutfit.isToday = marksAsToday
            editingOutfit.topItem = selectedItem(for: selectedTopID)
            editingOutfit.bottomItem = selectedItem(for: selectedBottomID)
            editingOutfit.outerwearItem = selectedItem(for: selectedOuterwearID)
            editingOutfit.shoesItem = selectedItem(for: selectedShoesID)
            editingOutfit.bagItem = selectedItem(for: selectedBagID)
            editingOutfit.accessoryItem = selectedItem(for: selectedAccessoryID)
            editingOutfit.updatedAt = .now
            outfit = editingOutfit
        } else {
            outfit = OOTDOutfit(
                title: trimmedTitle,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                isToday: marksAsToday,
                topItem: selectedItem(for: selectedTopID),
                bottomItem: selectedItem(for: selectedBottomID),
                outerwearItem: selectedItem(for: selectedOuterwearID),
                shoesItem: selectedItem(for: selectedShoesID),
                bagItem: selectedItem(for: selectedBagID),
                accessoryItem: selectedItem(for: selectedAccessoryID)
            )
            modelContext.insert(outfit)
        }

        do {
            try modelContext.save()
            AppHaptics.success()
            onSaved?(outfit)
            dismiss()
        } catch {
            if editingOutfit == nil {
                modelContext.delete(outfit)
            }
            saveErrorMessage = error.localizedDescription
            showsSaveError = true
        }
    }
}

private extension CreateOOTDView {
    enum OOTDSlot {
        case top
        case bottom
        case outerwear
        case shoes
        case bag
        case accessory

        var categories: [String] {
            switch self {
            case .top:
                ["上装"]
            case .bottom:
                ["下装", "裙装"]
            case .outerwear:
                ["外套"]
            case .shoes:
                ["鞋履"]
            case .bag:
                ["包袋"]
            case .accessory:
                ["配饰", "帽子"]
            }
        }

        func matches(_ item: WardrobeItem) -> Bool {
            let normalizedName = item.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if conflictNameHints.contains(where: { normalizedName.contains($0) }) {
                return false
            }

            if categories.contains(item.category) {
                return true
            }

            return nameHints.contains { normalizedName.contains($0) }
        }

        private var nameHints: [String] {
            switch self {
            case .top:
                ["上衣", "短袖", "长袖", "t恤", "tee", "shirt", "衬衫", "卫衣", "毛衣", "背心", "top"]
            case .bottom:
                ["裤", "裙", "牛仔", "pants", "trousers", "jeans", "skirt", "shorts"]
            case .outerwear:
                ["外套", "夹克", "风衣", "大衣", "开衫", "jacket", "coat", "outerwear"]
            case .shoes:
                ["鞋", "靴", "sneaker", "shoe", "boot", "loafer"]
            case .bag:
                ["包", "背包", "托特", "handbag", "bag", "tote", "backpack"]
            case .accessory:
                ["配饰", "帽", "耳", "项链", "戒指", "手表", "围巾", "accessory", "hat", "cap", "scarf", "watch"]
            }
        }

        private var conflictNameHints: [String] {
            switch self {
            case .top:
                ["裤", "裙", "鞋", "靴", "包"]
            case .bottom:
                ["鞋", "靴", "包"]
            case .outerwear:
                ["裤", "裙", "鞋", "靴", "包"]
            case .shoes:
                ["裤", "裙", "上衣", "短袖", "长袖", "衬衫", "外套", "包"]
            case .bag:
                ["裤", "裙", "鞋", "靴", "上衣", "短袖", "长袖", "衬衫", "外套"]
            case .accessory:
                ["裤", "裙", "鞋", "靴", "上衣", "短袖", "长袖", "衬衫", "外套", "包"]
            }
        }
    }

    static func initialSelection(for item: WardrobeItem?, slot: OOTDSlot) -> PersistentIdentifier? {
        guard let item, slot.categories.contains(item.category) else { return nil }
        return item.persistentModelID
    }

    static func prefilledSlotTitle(for item: WardrobeItem) -> String? {
        if OOTDSlot.top.categories.contains(item.category) { return "上装" }
        if OOTDSlot.bottom.categories.contains(item.category) { return "下装" }
        if OOTDSlot.outerwear.categories.contains(item.category) { return "外套" }
        if OOTDSlot.shoes.categories.contains(item.category) { return "鞋子" }
        if OOTDSlot.bag.categories.contains(item.category) { return "包" }
        if OOTDSlot.accessory.categories.contains(item.category) { return "配饰" }
        return nil
    }

    @ViewBuilder
    func ootdTextField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
        }
    }

    @ViewBuilder
    func ootdSelectorRow(
        title: String,
        subtitle: String,
        items: [WardrobeItem],
        selectedID: Binding<PersistentIdentifier?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectedItem(for: selectedID.wrappedValue)?.name ?? subtitle)
                    .font(.caption)
                    .foregroundStyle(selectedID.wrappedValue == nil ? Color.secondary : Color.primary.opacity(0.82))
            }

            if items.isEmpty {
                Text("暂无可选\(title)单品，先回衣橱添加对应分类。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            let isSelected = selectedID.wrappedValue == item.persistentModelID

                            Button {
                                selectedID.wrappedValue = isSelected ? nil : item.persistentModelID
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(item.tintColor.gradient)
                                        .frame(width: 88, height: 88)
                                        .overlay {
                                            if let imageData = item.imageData, let image = WardrobePlatformImage(data: imageData) {
                                                #if canImport(UIKit)
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                #elseif canImport(AppKit)
                                                Image(nsImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                                #endif
                                            } else {
                                                Image(systemName: item.imageSymbol)
                                                    .font(.title3.weight(.semibold))
                                                    .foregroundStyle(.white.opacity(0.94))
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(alignment: .topTrailing) {
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.headline)
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(.white, Color.accentColor)
                                                    .padding(6)
                                            }
                                        }

                                    Text(item.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .frame(width: 100, alignment: .leading)
                                .padding(10)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .glassCard(
                                cornerRadius: HomeMetrics.secondaryRadius,
                                tint: isSelected ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.12)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: HomeMetrics.secondaryRadius, style: .continuous)
                                    .stroke(isSelected ? Color.accentColor.opacity(0.72) : Color.clear, lineWidth: 2)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
    }
}

#Preview("Create OOTD") {
    NavigationStack {
        CreateOOTDView()
    }
    .modelContainer(WardrobePreviewContainer.shared)
}
