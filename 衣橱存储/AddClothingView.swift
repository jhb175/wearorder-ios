import PhotosUI
import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
private typealias BatchImportPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias BatchImportPlatformImage = NSImage
#endif

struct AddClothingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSaved: ((WardrobeItem) -> Void)? = nil

    @State private var draft = ClothingDraft()
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""
    @State private var isSavingClothing = false

    var body: some View {
        NavigationStack {
            ClothingEditorForm(
                draft: $draft,
                showsSaveSection: true,
                saveButtonTitle: "保存衣物",
                isSaveInProgress: isSavingClothing,
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
        guard !isSavingClothing else { return }
        let draftSnapshot = draft
        isSavingClothing = true
        Task {
            await saveClothing(draftSnapshot)
        }
    }

    private func saveClothing(_ draft: ClothingDraft) async {
        let itemID = UUID()
        var storedFiles: WardrobeStoredImageFiles?
        defer { isSavingClothing = false }

        do {
            storedFiles = try await Task.detached(priority: .userInitiated) {
                try WardrobeImageStoragePreparer.storeImageFilesIfNeeded(
                    itemID: itemID,
                    imageData: draft.imageData,
                    thumbnailData: draft.thumbnailData
                )
            }.value

            let newItem = WardrobeItem(
                id: itemID,
                name: draft.trimmedName,
                category: draft.category,
                colorName: draft.colorName,
                season: draft.season,
                imageSymbol: draft.imageSymbol,
                imageFileName: storedFiles?.imageFileName,
                thumbnailFileName: storedFiles?.thumbnailFileName,
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
            try modelContext.save()
            AppHaptics.success()
            onSaved?(newItem)
            dismiss()
        } catch {
            if let storedFiles {
                WardrobeImageFileStore.shared.remove(fileName: storedFiles.imageFileName)
                WardrobeImageFileStore.shared.remove(fileName: storedFiles.thumbnailFileName)
            }
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
            showsSaveError = true
        }
    }

}

enum BatchClothingImportMode: String, Identifiable {
    case photoLibrary
    case camera

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photoLibrary:
            "批量导入照片"
        case .camera:
            "批量拍照"
        }
    }

    var subtitle: String {
        switch self {
        case .photoLibrary:
            "一次选择多张照片，本地识别后批量加入衣橱。"
        case .camera:
            "连续拍摄多件衣物，确认后一次保存。"
        }
    }
}

private struct BatchClothingImportDraft: Identifiable, Sendable {
    let id: UUID = UUID()
    var name: String
    var category: String
    var colorName: String
    var season: String
    var imageSymbol: String
    var imageData: Data
    var thumbnailData: Data
    var sourceLabel: String
}

private struct PreparedBatchClothingImport: Sendable {
    let itemID: UUID
    let draft: BatchClothingImportDraft
    let storedFiles: WardrobeStoredImageFiles?
}

struct BatchClothingImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: BatchClothingImportMode
    let onSaved: (Int) -> Void

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var drafts: [BatchClothingImportDraft] = []
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var failureMessage: String?
    #if canImport(UIKit)
    @State private var showsCameraCapture = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    importActionSection
                    reviewSection
                }
                .padding(.horizontal, HomeMetrics.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(batchImportBackground)
            .navigationTitle(mode.title)
            .homeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveDrafts()
                        }
                    }
                    .disabled(drafts.isEmpty || isProcessing || isSaving)
                }
            }
            .task(id: selectedPhotoItems) {
                await importSelectedPhotoItemsIfNeeded()
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showsCameraCapture) {
                CameraCaptureView { imageData in
                    Task {
                        await importCameraImage(imageData)
                    }
                }
            }
            #endif
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(mode.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                batchSummaryChip(title: "待保存", value: "\(drafts.count)")
                batchSummaryChip(title: "处理方式", value: "本地")
                batchSummaryChip(title: "照片", value: "不上传")
            }

            if let statusMessage {
                batchStatusRow(text: statusMessage, systemImage: "checkmark.circle")
            }
            if let failureMessage {
                batchStatusRow(text: failureMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var importActionSection: some View {
        switch mode {
        case .photoLibrary:
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 80,
                matching: .images
            ) {
                Label(drafts.isEmpty ? "选择多张照片" : "继续选择照片", systemImage: "photo.on.rectangle.angled")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .disabled(isProcessing || isSaving)
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))

        case .camera:
            #if canImport(UIKit)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showsCameraCapture = true
                } label: {
                    Label(drafts.isEmpty ? "开始拍照" : "继续拍照", systemImage: "camera.fill")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .disabled(isProcessing || isSaving)
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
            } else {
                batchStatusRow(text: "当前设备不可用相机。请在真机上使用批量拍照，或改用批量导入照片。", systemImage: "camera.fill")
            }
            #else
            batchStatusRow(text: "当前平台不支持相机拍照。", systemImage: "camera.fill")
            #endif
        }

        if isProcessing || isSaving {
            HStack(spacing: 10) {
                ProgressView()
                Text(isSaving ? "正在保存到本地衣橱..." : "正在本地处理照片...")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    @ViewBuilder
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("入库预览")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(drafts.isEmpty ? "待选择" : "\(drafts.count) 件")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if drafts.isEmpty {
                batchEmptyCard
            } else {
                LazyVStack(spacing: 12) {
                    ForEach($drafts) { $draft in
                        batchDraftRow($draft)
                    }
                }
            }
        }
    }

    private var batchEmptyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: mode == .photoLibrary ? "photo.on.rectangle" : "camera")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .homeCardSurface(weight: .tertiary, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(mode == .photoLibrary ? "还没有选择照片" : "还没有拍摄照片")
                    .font(.headline)
                Text("批量处理会自动压缩图片、生成缩略图，并尝试识别分类和颜色。保存前可以逐件改名称和分类。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func batchDraftRow(_ draft: Binding<BatchClothingImportDraft>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BatchImportThumbnail(
                data: draft.wrappedValue.thumbnailData,
                symbolName: draft.wrappedValue.imageSymbol,
                cacheKey: draft.wrappedValue.id.uuidString
            )
                .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 10) {
                TextField("名称", text: draft.name)
                    .font(.subheadline.weight(.semibold))
                    .textFieldStyle(.plain)
                    .onChange(of: draft.wrappedValue.name) { _, newName in
                        guard let hint = WardrobeCategory.strongNameHint(for: newName),
                              WardrobeCategory.shouldApplyStrongNameHint(hint, over: draft.wrappedValue.category) else {
                            return
                        }
                        draft.wrappedValue.category = hint.rawValue
                        draft.wrappedValue.imageSymbol = hint.defaultSymbolName
                    }

                HStack(spacing: 8) {
                    Picker("分类", selection: draft.category) {
                        ForEach(WardrobeCategory.allCases, id: \.rawValue) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: draft.wrappedValue.category) { _, newCategory in
                        draft.wrappedValue.imageSymbol = WardrobeCategory(rawValue: newCategory)?.defaultSymbolName ?? "sparkles"
                    }

                    Picker("颜色", selection: draft.colorName) {
                        ForEach(ClothingPalette.presets, id: \.self) { color in
                            Text(color).tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(spacing: 8) {
                    Picker("季节", selection: draft.season) {
                        ForEach(ClothingSeason.allCases, id: \.rawValue) { season in
                            Text(season.rawValue).tag(season.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(draft.wrappedValue.sourceLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button(role: .destructive) {
                        removeDraft(id: draft.wrappedValue.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing || isSaving)
                }
            }
        }
        .padding(12)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func importSelectedPhotoItemsIfNeeded() async {
        let photoItems = selectedPhotoItems
        guard !photoItems.isEmpty else { return }
        selectedPhotoItems = []
        await importPhotoItems(photoItems)
    }

    private func importPhotoItems(_ photoItems: [PhotosPickerItem]) async {
        guard !photoItems.isEmpty else { return }
        isProcessing = true
        failureMessage = nil
        statusMessage = "准备处理 \(photoItems.count) 张照片。"
        let startingIndex = drafts.count
        var importedCount = 0
        var failedCount = 0

        var newDrafts: [BatchClothingImportDraft] = []
        for (offset, photoItem) in photoItems.enumerated() {
            statusMessage = "正在处理第 \(offset + 1)/\(photoItems.count) 张照片。"
            do {
                guard let imageData = try await photoItem.loadTransferable(type: Data.self) else {
                    failedCount += 1
                    continue
                }
                let draft = await makeDraft(from: imageData, sourceLabel: "相册第 \(startingIndex + importedCount + 1) 张", displayIndex: startingIndex + importedCount + 1)
                newDrafts.append(draft)
                importedCount += 1
            } catch {
                failedCount += 1
            }
        }

        if !newDrafts.isEmpty {
            drafts.append(contentsOf: newDrafts)
        }

        isProcessing = false
        if importedCount > 0 {
            statusMessage = "已加入 \(importedCount) 件待保存衣物。"
        }
        if failedCount > 0 {
            failureMessage = "\(failedCount) 张照片读取失败，请重试或换一张图。"
        }
    }

    private func importCameraImage(_ imageData: Data) async {
        isProcessing = true
        failureMessage = nil
        statusMessage = "正在处理刚拍摄的照片。"
        let draft = await makeDraft(from: imageData, sourceLabel: "拍照第 \(drafts.count + 1) 张", displayIndex: drafts.count + 1)
        drafts.append(draft)
        isProcessing = false
        statusMessage = "已加入 1 件待保存衣物，可以继续拍照。"
    }

    private func makeDraft(from imageData: Data, sourceLabel: String, displayIndex: Int) async -> BatchClothingImportDraft {
        let processed = await Task.detached(priority: .userInitiated) {
            ClothingImageImportProcessor.process(imageData)
        }.value
        let category = processed.categorySuggestion?.category ?? .other
        let colorName = processed.colorSuggestion?.colorName ?? "奶油白"

        return BatchClothingImportDraft(
            name: "\(category.rawValue) \(displayIndex)",
            category: category.rawValue,
            colorName: colorName,
            season: ClothingSeason.all.rawValue,
            imageSymbol: category.defaultSymbolName,
            imageData: processed.optimizedData,
            thumbnailData: processed.thumbnailData,
            sourceLabel: sourceLabel
        )
    }

    private func saveDrafts() async {
        guard !isSaving else { return }
        let validDrafts = drafts.map { draft in
            var copy = draft
            let trimmedName = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                copy.name = "\(copy.category) \(drafts.firstIndex(where: { $0.id == copy.id }).map { $0 + 1 } ?? 1)"
            } else {
                copy.name = trimmedName
            }
            return copy
        }
        guard !validDrafts.isEmpty else { return }

        isSaving = true
        failureMessage = nil
        let importBatchID = UUID()
        var preparedImports: [PreparedBatchClothingImport] = []

        do {
            preparedImports = try await Task.detached(priority: .userInitiated) {
                try validDrafts.map { draft in
                    let itemID = UUID()
                    let storedFiles = try WardrobeImageStoragePreparer.storeImageFilesIfNeeded(
                        itemID: itemID,
                        imageData: draft.imageData,
                        thumbnailData: draft.thumbnailData
                    )
                    return PreparedBatchClothingImport(itemID: itemID, draft: draft, storedFiles: storedFiles)
                }
            }.value
        } catch {
            isSaving = false
            failureMessage = "批量保存失败：\(error.localizedDescription)"
            return
        }

        let insertedItems: [WardrobeItem] = preparedImports.map { prepared in
            let draft = prepared.draft
            return WardrobeItem(
                id: prepared.itemID,
                name: draft.name,
                category: draft.category,
                colorName: draft.colorName,
                season: draft.season,
                imageSymbol: draft.imageSymbol,
                imageFileName: prepared.storedFiles?.imageFileName,
                thumbnailFileName: prepared.storedFiles?.thumbnailFileName,
                importBatchID: importBatchID
            )
        }

        var insertedCount = 0
        do {
            for item in insertedItems {
                modelContext.insert(item)
                insertedCount += 1
            }
            try modelContext.save()
            AppHaptics.success()
            isSaving = false
            onSaved(insertedItems.count)
            dismiss()
        } catch {
            for item in insertedItems.prefix(insertedCount) {
                modelContext.delete(item)
            }
            for prepared in preparedImports {
                if let storedFiles = prepared.storedFiles {
                    WardrobeImageFileStore.shared.remove(fileName: storedFiles.imageFileName)
                    WardrobeImageFileStore.shared.remove(fileName: storedFiles.thumbnailFileName)
                }
            }
            modelContext.rollback()
            isSaving = false
            failureMessage = "批量保存失败：\(error.localizedDescription)"
        }
    }

    private func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        AppHaptics.selection()
    }

    private func batchSummaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
    }

    private func batchStatusRow(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var batchImportBackground: some View {
        AppAdaptiveBackground()
    }
}

private struct BatchImportThumbnail: View {
    let data: Data
    let symbolName: String
    let cacheKey: String
    #if canImport(UIKit) || canImport(AppKit)
    @State private var decodedImage: BatchImportPlatformImage?
    #endif

    var body: some View {
        ZStack {
            #if canImport(UIKit) || canImport(AppKit)
            if let decodedImage {
                platformImageView(decodedImage)
            } else {
                placeholderImage
            }
            #else
            placeholderImage
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: HomeMetrics.innerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HomeMetrics.innerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        }
        .clipped()
        .task(id: cacheKey) {
            #if canImport(UIKit) || canImport(AppKit)
            await decodeThumbnailIfNeeded()
            #endif
        }
    }

    private var placeholderImage: some View {
        Image(systemName: symbolName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    #if canImport(UIKit) || canImport(AppKit)
    @ViewBuilder
    private func platformImageView(_ image: BatchImportPlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
        #endif
    }

    private func decodeThumbnailIfNeeded() async {
        decodedImage = nil
        let thumbnailData = data
        let decoded = await Task.detached(priority: .utility) {
            BatchImportThumbnail.decodeImage(from: thumbnailData)
        }.value
        guard !Task.isCancelled else { return }
        decodedImage = decoded
    }

    private nonisolated static func decodeImage(from data: Data) -> BatchImportPlatformImage? {
        #if canImport(UIKit)
        UIImage(data: data)
        #elseif canImport(AppKit)
        NSImage(data: data)
        #endif
    }
    #endif
}

enum WardrobeCategory: String, CaseIterable, Sendable {
    case top = "上装"
    case tshirt = "T恤"
    case shirt = "衬衫"
    case blouse = "雪纺/罩衫"
    case knitwear = "针织衫"
    case sweater = "毛衣"
    case hoodie = "卫衣"
    case camisole = "背心/吊带"
    case polo = "Polo衫"
    case outerwear = "外套"
    case jacket = "夹克"
    case blazer = "西装外套"
    case cardigan = "开衫"
    case trenchCoat = "风衣"
    case coat = "大衣"
    case downJacket = "羽绒服"
    case leatherJacket = "皮衣"
    case vest = "马甲"
    case bottom = "下装"
    case jeans = "牛仔裤"
    case casualPants = "休闲裤"
    case suitPants = "西裤"
    case shorts = "短裤"
    case sportsPants = "运动裤"
    case cargoPants = "工装裤"
    case leggings = "打底裤"
    case skirt = "裙装"
    case pleatedSkirt = "百褶裙"
    case miniSkirt = "短裙"
    case dress = "连衣裙"
    case gown = "礼服"
    case qipao = "旗袍"
    case set = "套装"
    case jumpsuit = "连体裤"
    case sportswear = "运动服"
    case swimwear = "泳装"
    case shoes = "鞋履"
    case sneakers = "运动鞋"
    case casualShoes = "休闲鞋"
    case boots = "靴子"
    case sandals = "凉鞋"
    case heels = "高跟鞋"
    case slippers = "拖鞋"
    case loafers = "乐福鞋"
    case bag = "包袋"
    case toteBag = "托特包"
    case shoulderBag = "单肩/斜挎包"
    case backpack = "双肩包"
    case clutch = "手拿包"
    case wallet = "钱包/卡包"
    case luggage = "行李箱"
    case accessory = "配饰"
    case hat = "帽子"
    case scarf = "围巾/披肩"
    case belt = "腰带"
    case jewelry = "首饰"
    case earrings = "耳饰"
    case necklace = "项链"
    case braceletRing = "手链/戒指"
    case watch = "手表"
    case eyewear = "眼镜/墨镜"
    case hairAccessory = "发饰"
    case socks = "袜子"
    case tie = "领带/领结"
    case loungewear = "内衣家居"
    case underwear = "内衣"
    case pajamas = "睡衣/家居服"
    case kids = "童装"
    case pet = "宠物服装"
    case other = "其他"

    enum FunctionalGroup: Sendable {
        case top
        case outerwear
        case lowerBody
        case onePiece
        case shoes
        case bag
        case accessory
        case loungewear
        case kids
        case pet
        case other
    }

    var defaultSymbolName: String {
        switch self {
        case .top, .tshirt, .shirt, .blouse, .knitwear, .sweater, .hoodie, .camisole, .polo:
            "shirt.fill"
        case .outerwear, .jacket, .blazer, .cardigan, .trenchCoat, .coat, .downJacket, .leatherJacket, .vest:
            "jacket.fill"
        case .bottom, .jeans, .casualPants, .suitPants, .shorts, .sportsPants, .cargoPants, .leggings:
            "figure.walk"
        case .skirt, .pleatedSkirt, .miniSkirt:
            "sun.max.trianglebadge.exclamationmark"
        case .dress, .gown, .qipao:
            "person.fill"
        case .set, .jumpsuit, .sportswear, .swimwear:
            "square.grid.2x2.fill"
        case .shoes, .sneakers, .casualShoes, .boots, .sandals, .heels, .slippers, .loafers:
            "shoe.2.fill"
        case .bag, .toteBag, .shoulderBag, .backpack, .clutch, .wallet, .luggage:
            "bag.fill"
        case .accessory, .jewelry, .earrings, .necklace, .braceletRing:
            "circle.hexagongrid.fill"
        case .hat:
            "cap.fill"
        case .scarf:
            "scarf"
        case .belt:
            "belt"
        case .watch:
            "watch.analog"
        case .eyewear:
            "eyeglasses"
        case .hairAccessory:
            "sparkles"
        case .socks:
            "shoeprints.fill"
        case .tie:
            "person.crop.rectangle"
        case .loungewear, .underwear, .pajamas:
            "house.fill"
        case .kids:
            "person.2.fill"
        case .pet:
            "pawprint.fill"
        case .other:
            "sparkles"
        }
    }

    var filterOrder: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }

    nonisolated var functionalGroup: FunctionalGroup {
        switch self {
        case .top, .tshirt, .shirt, .blouse, .knitwear, .sweater, .hoodie, .camisole, .polo:
            .top
        case .outerwear, .jacket, .blazer, .cardigan, .trenchCoat, .coat, .downJacket, .leatherJacket, .vest:
            .outerwear
        case .bottom, .jeans, .casualPants, .suitPants, .shorts, .sportsPants, .cargoPants, .leggings, .skirt, .pleatedSkirt, .miniSkirt:
            .lowerBody
        case .dress, .gown, .qipao, .set, .jumpsuit, .sportswear, .swimwear:
            .onePiece
        case .shoes, .sneakers, .casualShoes, .boots, .sandals, .heels, .slippers, .loafers:
            .shoes
        case .bag, .toteBag, .shoulderBag, .backpack, .clutch, .wallet, .luggage:
            .bag
        case .accessory, .hat, .scarf, .belt, .jewelry, .earrings, .necklace, .braceletRing, .watch, .eyewear, .hairAccessory, .socks, .tie:
            .accessory
        case .loungewear, .underwear, .pajamas:
            .loungewear
        case .kids:
            .kids
        case .pet:
            .pet
        case .other:
            .other
        }
    }

    var isGenericCategory: Bool {
        switch self {
        case .top, .outerwear, .bottom, .skirt, .dress, .set, .shoes, .bag, .accessory, .loungewear, .other:
            true
        case .tshirt, .shirt, .blouse, .knitwear, .sweater, .hoodie, .camisole, .polo,
             .jacket, .blazer, .cardigan, .trenchCoat, .coat, .downJacket, .leatherJacket, .vest,
             .jeans, .casualPants, .suitPants, .shorts, .sportsPants, .cargoPants, .leggings,
             .pleatedSkirt, .miniSkirt, .gown, .qipao, .jumpsuit, .sportswear, .swimwear,
             .sneakers, .casualShoes, .boots, .sandals, .heels, .slippers, .loafers,
             .toteBag, .shoulderBag, .backpack, .clutch, .wallet, .luggage,
             .hat, .scarf, .belt, .jewelry, .earrings, .necklace, .braceletRing, .watch, .eyewear, .hairAccessory, .socks, .tie,
             .underwear, .pajamas, .kids, .pet:
            false
        }
    }

    var isCoreWardrobeCategory: Bool {
        Self.topSlotCategories.contains(self) ||
        Self.lowerBodyCategories.contains(self) ||
        Self.onePieceCategories.contains(self) ||
        Self.shoesCategories.contains(self)
    }

    var isLowerBodyOrOnePiece: Bool {
        Self.lowerBodyCategories.contains(self) || Self.onePieceCategories.contains(self)
    }

    static let topSlotCategories: [WardrobeCategory] = [
        .top, .tshirt, .shirt, .blouse, .knitwear, .sweater, .hoodie, .camisole, .polo
    ]

    static let outerwearCategories: [WardrobeCategory] = [
        .outerwear, .jacket, .blazer, .cardigan, .trenchCoat, .coat, .downJacket, .leatherJacket, .vest
    ]

    static let lowerBodyCategories: [WardrobeCategory] = [
        .bottom, .jeans, .casualPants, .suitPants, .shorts, .sportsPants, .cargoPants, .leggings,
        .skirt, .pleatedSkirt, .miniSkirt
    ]

    static let onePieceCategories: [WardrobeCategory] = [
        .dress, .gown, .qipao, .set, .jumpsuit, .sportswear, .swimwear
    ]

    static let shoesCategories: [WardrobeCategory] = [
        .shoes, .sneakers, .casualShoes, .boots, .sandals, .heels, .slippers, .loafers
    ]

    static let bagCategories: [WardrobeCategory] = [
        .bag, .toteBag, .shoulderBag, .backpack, .clutch, .wallet, .luggage
    ]

    static let accessoryCategories: [WardrobeCategory] = [
        .accessory, .hat, .scarf, .belt, .jewelry, .earrings, .necklace, .braceletRing, .watch, .eyewear, .hairAccessory, .socks, .tie
    ]

    static var topSlotRawValues: [String] { topSlotCategories.map(\.rawValue) }
    static var outerwearRawValues: [String] { outerwearCategories.map(\.rawValue) }
    static var lowerBodyRawValues: [String] { lowerBodyCategories.map(\.rawValue) }
    static var onePieceRawValues: [String] { onePieceCategories.map(\.rawValue) }
    static var ootdBottomSlotRawValues: [String] { lowerBodyRawValues + onePieceRawValues }
    static var shoesRawValues: [String] { shoesCategories.map(\.rawValue) }
    static var bagRawValues: [String] { bagCategories.map(\.rawValue) }
    static var accessoryRawValues: [String] { accessoryCategories.map(\.rawValue) }

    static func orderedRawValues(from categories: some Sequence<String>) -> [String] {
        let categorySet = Set(categories)
        let known = allCases
            .map(\.rawValue)
            .filter { categorySet.contains($0) }
        let unknown = categorySet
            .filter { WardrobeCategory(rawValue: $0) == nil }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return known + unknown
    }

    static func strongNameHint(for name: String) -> WardrobeCategory? {
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return nil }

        let rules: [(WardrobeCategory, [String])] = [
            (.pet, ["宠物", "狗狗", "猫咪", "pet", "dog", "cat"]),
            (.kids, ["童装", "儿童", "宝宝", "婴儿", "女童", "男童", "kids", "kid", "child", "baby"]),
            (.sneakers, ["运动鞋", "跑鞋", "板鞋", "球鞋", "sneaker", "sneakers", "running shoe"]),
            (.boots, ["靴子", "短靴", "长靴", "马丁靴", "boot", "boots"]),
            (.sandals, ["凉鞋", "凉拖", "sandal", "sandals"]),
            (.heels, ["高跟鞋", "单鞋", "heels", "pump"]),
            (.slippers, ["拖鞋", "人字拖", "slipper", "slippers", "flip flop"]),
            (.loafers, ["乐福鞋", "loafer", "loafers"]),
            (.pleatedSkirt, ["百褶裙", "pleated skirt"]),
            (.miniSkirt, ["短裙", "mini skirt", "miniskirt"]),
            (.skirt, ["半身裙", "长裙", "a字裙", "包臀裙", "skirt"]),
            (.jeans, ["牛仔裤", "jeans", "denim"]),
            (.suitPants, ["西裤", "正装裤", "slacks", "dress pants", "suit pants"]),
            (.shorts, ["短裤", "shorts"]),
            (.sportsPants, ["运动裤", "卫裤", "jogger", "joggers", "sweatpants"]),
            (.cargoPants, ["工装裤", "cargo pants"]),
            (.leggings, ["打底裤", "瑜伽裤", "leggings", "yoga pants"]),
            (.bottom, ["裤子", "长裤", "阔腿裤", "裤", "pants", "trousers"]),
            (.qipao, ["旗袍", "cheongsam", "qipao"]),
            (.gown, ["礼服", "长裙礼服", "晚礼服", "gown", "evening dress", "formal dress"]),
            (.dress, ["连衣裙", "dress", "onepiece", "one piece"]),
            (.jumpsuit, ["连体裤", "背带裤", "jumpsuit", "romper", "overall", "overalls"]),
            (.swimwear, ["泳衣", "泳装", "比基尼", "swimwear", "swimsuit", "bikini"]),
            (.sportswear, ["运动套装", "健身服", "瑜伽服", "sportswear", "activewear", "tracksuit"]),
            (.set, ["套装", "两件套", "三件套", "jk套装", "制服套装", "set", "suit set", "matching set"]),
            (.downJacket, ["羽绒服", "down jacket", "puffer"]),
            (.trenchCoat, ["风衣", "trench"]),
            (.leatherJacket, ["皮衣", "leather jacket"]),
            (.blazer, ["西装外套", "小西装", "blazer"]),
            (.cardigan, ["开衫", "cardigan"]),
            (.coat, ["大衣", "coat", "overcoat"]),
            (.jacket, ["夹克", "jacket"]),
            (.vest, ["马甲", "vest"]),
            (.outerwear, ["外套", "outerwear"]),
            (.hoodie, ["卫衣", "hoodie", "sweatshirt"]),
            (.sweater, ["毛衣", "sweater", "jumper"]),
            (.knitwear, ["针织", "针织衫", "knit", "knitwear"]),
            (.camisole, ["吊带", "背心", "tank top", "camisole", "vest top"]),
            (.polo, ["polo", "polo衫"]),
            (.tshirt, ["短袖", "长袖", "t恤", "T恤", "tee", "t shirt", "tshirt"]),
            (.shirt, ["衬衫", "shirt"]),
            (.blouse, ["雪纺", "罩衫", "blouse"]),
            (.top, ["上衣", "水手服", "海军领", "jk上衣", "jk 上衣", "制服上衣", "top"]),
            (.toteBag, ["托特包", "tote"]),
            (.backpack, ["背包", "双肩包", "backpack"]),
            (.shoulderBag, ["单肩包", "斜挎包", "腋下包", "shoulder bag", "crossbody"]),
            (.clutch, ["手拿包", "晚宴包", "clutch"]),
            (.wallet, ["钱包", "卡包", "wallet", "card holder"]),
            (.luggage, ["行李箱", "旅行箱", "suitcase", "luggage"]),
            (.bag, ["包包", "手袋", "包", "bag", "handbag", "purse"]),
            (.hat, ["帽子", "棒球帽", "渔夫帽", "帽", "hat", "cap", "beanie"]),
            (.scarf, ["围巾", "披肩", "丝巾", "scarf", "shawl"]),
            (.belt, ["腰带", "皮带", "belt"]),
            (.earrings, ["耳饰", "耳环", "耳钉", "earring", "earrings"]),
            (.necklace, ["项链", "necklace"]),
            (.braceletRing, ["手链", "手镯", "戒指", "bracelet", "ring"]),
            (.watch, ["手表", "watch"]),
            (.eyewear, ["眼镜", "墨镜", "太阳镜", "glasses", "sunglasses", "eyewear"]),
            (.hairAccessory, ["发饰", "发夹", "发箍", "hair clip", "headband"]),
            (.socks, ["袜子", "袜", "socks", "stockings"]),
            (.tie, ["领带", "领结", "tie", "bow tie"]),
            (.jewelry, ["首饰", "珠宝", "jewelry", "jewellery"]),
            (.accessory, ["配饰", "accessory", "accessories"]),
            (.underwear, ["内衣", "内裤", "bra", "underwear", "lingerie"]),
            (.pajamas, ["睡衣", "家居服", "pajama", "pyjama", "sleepwear", "homewear"]),
            (.loungewear, ["内衣家居", "loungewear"])
        ]

        return rules.first { _, keywords in
            keywords.contains { normalized.contains($0) }
        }?.0
    }

    static func shouldApplyStrongNameHint(_ hint: WardrobeCategory, over currentCategory: String) -> Bool {
        guard let current = WardrobeCategory(rawValue: currentCategory) else { return true }
        if current == hint { return false }

        switch (current, hint) {
        case (.other, _), (_, .pet), (_, .kids):
            return true
        default:
            break
        }

        if current.functionalGroup != hint.functionalGroup {
            return true
        }

        if current.isGenericCategory, !hint.isGenericCategory {
            return true
        }

        if current.functionalGroup == .accessory, !hint.isGenericCategory {
            return true
        }

        return false
    }
}

enum ClothingSeason: String, CaseIterable, Sendable {
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
