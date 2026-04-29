import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ClothingDraft {
    var name: String = ""
    var category: String = WardrobeCategory.top.rawValue
    var colorName: String = "奶油白"
    var season: String = ClothingSeason.all.rawValue
    var styleTagsText: String = ""
    var notes: String = ""
    var brand: String = ""
    var size: String = ""
    var purchasePriceText: String = ""
    var hasPurchaseDate: Bool = false
    var purchaseDate: Date = .now
    var purchaseChannel: String = ""
    var careNotes: String = ""
    var imageData: Data? = nil
    var thumbnailData: Data? = nil

    init() {}

    init(item: WardrobeItem) {
        name = item.name
        category = item.category
        colorName = item.colorName
        season = item.season
        styleTagsText = item.styleTagsText
        notes = item.notes
        brand = item.trimmedBrand ?? ""
        size = item.trimmedSize ?? ""
        purchasePriceText = item.purchasePrice.map { Self.priceInputFormatter.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? ""
        hasPurchaseDate = item.purchaseDate != nil
        purchaseDate = item.purchaseDate ?? .now
        purchaseChannel = item.trimmedPurchaseChannel ?? ""
        careNotes = item.trimmedCareNotes ?? ""
        imageData = item.displayImageData
        thumbnailData = item.preferredThumbnailData
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedName.isEmpty && isPurchasePriceValid
    }

    var normalizedPurchasePrice: Double? {
        let trimmed = purchasePriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let value = Self.parsePurchasePrice(trimmed), value >= 0 else { return nil }
        return value
    }

    var isPurchasePriceValid: Bool {
        purchasePriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || normalizedPurchasePrice != nil
    }

    var colorPreview: Color {
        ClothingPalette.color(for: colorName)
    }

    var imageSymbol: String {
        WardrobeCategory(rawValue: category)?.defaultSymbolName ?? "sparkles"
    }

    private static let priceInputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static func parsePurchasePrice(_ text: String) -> Double? {
        let compact = text
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "元", with: "")
            .replacingOccurrences(of: " ", with: "")

        if compact.contains("."), compact.contains(",") {
            return Double(compact.replacingOccurrences(of: ",", with: ""))
        }

        if compact.contains(",") {
            let parts = compact.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count > 1,
               parts.dropFirst().allSatisfy({ $0.count == 3 }),
               parts.first?.isEmpty == false {
                return Double(parts.joined())
            }
            return Double(compact.replacingOccurrences(of: ",", with: "."))
        }

        return Double(compact)
    }
}

struct ProcessedClothingImageImport: Sendable {
    let originalByteCount: Int
    let optimizedData: Data
    let thumbnailData: Data
    let colorSuggestion: ClothingImageColorSuggestion?
    let categorySuggestion: ClothingImageCategorySuggestion?
}

enum ClothingImageImportProcessor {
    nonisolated static func process(_ imageData: Data) -> ProcessedClothingImageImport {
        let optimizedData = ImageDataOptimizer.optimizedJPEGData(from: imageData) ?? imageData
        let thumbnailData = ImageDataOptimizer.thumbnailJPEGData(from: optimizedData) ?? optimizedData
        return ProcessedClothingImageImport(
            originalByteCount: imageData.count,
            optimizedData: optimizedData,
            thumbnailData: thumbnailData,
            colorSuggestion: ClothingImageAnalyzer.suggestDominantColor(from: optimizedData),
            categorySuggestion: ClothingImageAnalyzer.suggestCategory(from: optimizedData)
        )
    }
}

struct ClothingEditorForm: View {
    @Binding var draft: ClothingDraft
    let showsSaveSection: Bool
    let saveButtonTitle: String
    let onSave: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageImportStatus: ClothingImageImportStatus?
    @State private var imageImportFailureMessage: String?
    @State private var isImportingImage = false
    @State private var imageMutationToken = UUID()
    @State private var isGeneratingWhiteBackground = false
    @State private var whiteBackgroundMessage: String?
    @State private var whiteBackgroundFailureMessage: String?
    @State private var imageColorSuggestion: ClothingImageColorSuggestion?
    @State private var imageCategorySuggestion: ClothingImageCategorySuggestion?
    @State private var didAutoApplyImageColor = false
    @State private var didAutoApplyImageCategory = false
    @State private var didPrepareSmartFill = false
    @State private var hasUserEditedColor = false
    @State private var hasUserEditedCategory = false
    #if canImport(UIKit)
    @State private var showsCameraCapture = false
    #endif
    private let commonStyleTags = ["通勤", "休闲", "极简", "轻松", "正式", "舒适", "层次", "轻甜"]

    var body: some View {
        Form {
            imageSection
            infoSection
            purchaseSection
            styleSection

            if showsSaveSection {
                Section {
                    Button(action: onSave) {
                        Text(saveButtonTitle)
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!draft.isValid || isImportingImage || isGeneratingWhiteBackground)
                }
            }
        }
        .task(id: selectedPhotoItem) {
            await loadPhotoIfNeeded()
        }
        .onAppear {
            prepareSmartFillStateIfNeeded()
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showsCameraCapture) {
            CameraCaptureView { imageData in
                Task {
                    await applyImportedImageData(imageData)
                }
            }
        }
        #endif
    }

    private var imageSection: some View {
        Section("图片") {
            VStack(spacing: 14) {
                ClothingImagePreview(imageData: draft.imageData, imageSymbol: draft.imageSymbol, tintColor: draft.colorPreview)
                    .frame(height: 220)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 12)], spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(isImportingImage ? "处理中" : (draft.imageData == nil ? "从相册选择" : "替换图片"), systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .disabled(isImportingImage)
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))

                    #if canImport(UIKit)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            showsCameraCapture = true
                        } label: {
                            Label("拍照", systemImage: "camera")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .disabled(isImportingImage)
                        .buttonStyle(HomePressableButtonStyle())
                        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
                    }
                    #endif

                    Button {
                        Task {
                            await generateWhiteBackgroundImage()
                        }
                    } label: {
                        Label(isGeneratingWhiteBackground ? "生成中" : "生成白底图", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .disabled(draft.imageData == nil || isImportingImage || isGeneratingWhiteBackground || !ClothingBackgroundImageProcessor.isWhiteBackgroundGenerationAvailable)
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))

                    Button {
                        clearImage()
                    } label: {
                        Label(draft.imageData == nil ? "清除图片" : "移除图片", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .disabled(draft.imageData == nil)
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
                }

                if isImportingImage {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在本地处理图片并生成缩略图，照片不会上传。")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                } else if isGeneratingWhiteBackground {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在本地生成白底图，照片不会上传。")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                } else if let whiteBackgroundFailureMessage {
                    Label(whiteBackgroundFailureMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                } else if let whiteBackgroundMessage {
                    imageStatusRow(text: whiteBackgroundMessage, systemImage: "wand.and.stars")
                } else if let imageImportFailureMessage {
                    Label(imageImportFailureMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                } else if let imageImportStatus {
                    imageStatusRow(
                        text: imageImportStatus.message,
                        systemImage: imageImportStatus.didCompress ? "arrow.down.forward.and.arrow.up.backward" : "photo"
                    )
                } else if let imageData = draft.imageData {
                    imageStatusRow(
                        text: "当前图片大小：\(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))",
                        systemImage: "photo"
                    )
                }

                if let imageCategorySuggestion {
                    imageCategorySuggestionRow(imageCategorySuggestion)
                }

                if let imageColorSuggestion {
                    imageColorSuggestionRow(imageColorSuggestion)
                }
            }
            .listRowBackground(Color.clear)
        }
    }

    private func imageStatusRow(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var infoSection: some View {
        Section("衣物信息") {
            TextField("名称", text: $draft.name)
                .onChange(of: draft.name) { _, newName in
                    applyNameCategoryHintIfNeeded(newName)
                }

            Picker("分类", selection: categoryBinding) {
                ForEach(WardrobeCategory.allCases, id: \.rawValue) { category in
                    Text(category.rawValue).tag(category.rawValue)
                }
            }

            Picker("颜色", selection: colorNameBinding) {
                ForEach(ClothingPalette.presets, id: \.self) { color in
                    Text(color).tag(color)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("常用颜色")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                    ForEach(ClothingPalette.presets, id: \.self) { color in
                        Button {
                            colorNameBinding.wrappedValue = color
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(ClothingPalette.color(for: color))
                                    .frame(width: 14, height: 14)
                                Text(color)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(draft.colorName == color ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
                        }
                    }
                }
            }

            TextField("自定义颜色名", text: colorNameBinding)

            Picker("季节", selection: $draft.season) {
                ForEach(ClothingSeason.allCases, id: \.rawValue) { season in
                    Text(season.rawValue).tag(season.rawValue)
                }
            }
            TextField("备注", text: $draft.notes, axis: .vertical)
                .lineLimit(3...5)
        }
    }

    private var purchaseSection: some View {
        Section("购买与保养") {
            TextField("品牌（可选）", text: $draft.brand)
            TextField("尺码（可选）", text: $draft.size)
            TextField("购买价格（可选）", text: $draft.purchasePriceText)
                .keyboardType(.decimalPad)

            if !draft.isPurchasePriceValid {
                Label("请输入有效的非负金额", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            Toggle("记录购买日期", isOn: $draft.hasPurchaseDate)
            if draft.hasPurchaseDate {
                DatePicker("购买日期", selection: $draft.purchaseDate, displayedComponents: .date)
            }

            TextField("购买渠道（可选）", text: $draft.purchaseChannel)
            TextField("保养备注（可选）", text: $draft.careNotes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    private var styleSection: some View {
        Section("风格标签") {
            TextField("风格标签，使用逗号分隔", text: $draft.styleTagsText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(commonStyleTags, id: \.self) { tag in
                    Button {
                        toggleStyleTag(tag)
                    } label: {
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(styleTags.contains(tag) ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
                    }
                }
            }
        }
    }

    private var styleTags: [String] {
        draft.styleTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var colorNameBinding: Binding<String> {
        Binding {
            draft.colorName
        } set: { newValue in
            draft.colorName = newValue
            hasUserEditedColor = true
        }
    }

    private var categoryBinding: Binding<String> {
        Binding {
            draft.category
        } set: { newValue in
            draft.category = newValue
            hasUserEditedCategory = true
        }
    }

    private func toggleStyleTag(_ tag: String) {
        var tags = styleTags
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
        } else {
            tags.append(tag)
        }
        draft.styleTagsText = tags.joined(separator: ", ")
    }

    private func applyNameCategoryHintIfNeeded(_ name: String) {
        guard !hasUserEditedCategory,
              let hint = WardrobeCategory.strongNameHint(for: name),
              WardrobeCategory.shouldApplyStrongNameHint(hint, over: draft.category) else {
            return
        }

        draft.category = hint.rawValue
        hasUserEditedCategory = true
        didAutoApplyImageCategory = true
    }

    private func loadPhotoIfNeeded() async {
        guard let selectedPhotoItem else { return }
        do {
            guard let imageData = try await selectedPhotoItem.loadTransferable(type: Data.self) else {
                imageImportStatus = nil
                imageImportFailureMessage = "图片导入失败，请重试或换一张图片。"
                return
            }
            await applyImportedImageData(imageData)
        } catch {
            imageImportStatus = nil
            imageImportFailureMessage = "图片导入失败，请重试或换一张图片。"
        }
    }

    private func applyImportedImageData(_ imageData: Data) async {
        let token = UUID()
        imageMutationToken = token
        isImportingImage = true
        imageImportFailureMessage = nil
        whiteBackgroundMessage = nil
        whiteBackgroundFailureMessage = nil
        imageImportStatus = nil
        imageColorSuggestion = nil
        imageCategorySuggestion = nil
        didAutoApplyImageColor = false
        didAutoApplyImageCategory = false

        let processedImport = await Task.detached(priority: .userInitiated) {
            ClothingImageImportProcessor.process(imageData)
        }.value

        guard imageMutationToken == token else { return }

        isImportingImage = false
        draft.imageData = processedImport.optimizedData
        draft.thumbnailData = processedImport.thumbnailData
        imageImportStatus = ClothingImageImportStatus(
            originalByteCount: processedImport.originalByteCount,
            storedByteCount: processedImport.optimizedData.count
        )

        let suggestion = processedImport.colorSuggestion
        imageColorSuggestion = suggestion
        if let suggestion, !hasUserEditedColor {
            draft.colorName = suggestion.colorName
            didAutoApplyImageColor = true
        }

        let categorySuggestion = processedImport.categorySuggestion
        imageCategorySuggestion = categorySuggestion
        if let categorySuggestion, !hasUserEditedCategory {
            draft.category = categorySuggestion.categoryName
            didAutoApplyImageCategory = true
        }
    }

    private func generateWhiteBackgroundImage() async {
        guard let imageData = draft.imageData, !isImportingImage, !isGeneratingWhiteBackground else { return }
        let sourceToken = imageMutationToken

        isGeneratingWhiteBackground = true
        whiteBackgroundMessage = nil
        whiteBackgroundFailureMessage = nil
        defer { isGeneratingWhiteBackground = false }

        do {
            let processedData = try await Task.detached(priority: .userInitiated) {
                try ClothingBackgroundImageProcessor.whiteBackgroundJPEGData(from: imageData)
            }.value

            guard imageMutationToken == sourceToken, draft.imageData == imageData else { return }

            draft.imageData = processedData
            draft.thumbnailData = ImageDataOptimizer.thumbnailJPEGData(from: processedData) ?? processedData
            imageMutationToken = UUID()
            whiteBackgroundMessage = "已生成白底图，用于衣橱展示和搭配选择。"
            imageImportStatus = ClothingImageImportStatus(
                originalByteCount: imageData.count,
                storedByteCount: processedData.count
            )
            imageImportFailureMessage = nil
        } catch let error as ClothingBackgroundImageProcessingError {
            guard imageMutationToken == sourceToken else { return }
            whiteBackgroundFailureMessage = error.userMessage
        } catch {
            guard imageMutationToken == sourceToken else { return }
            whiteBackgroundFailureMessage = "白底图生成失败，请重试或保留原图。"
        }
    }

    private func clearImage() {
        imageMutationToken = UUID()
        isImportingImage = false
        draft.imageData = nil
        draft.thumbnailData = nil
        selectedPhotoItem = nil
        imageImportStatus = nil
        imageImportFailureMessage = nil
        whiteBackgroundMessage = nil
        whiteBackgroundFailureMessage = nil
        imageColorSuggestion = nil
        imageCategorySuggestion = nil
        didAutoApplyImageColor = false
        didAutoApplyImageCategory = false
    }

    private func prepareSmartFillStateIfNeeded() {
        guard !didPrepareSmartFill else { return }
        didPrepareSmartFill = true
        let defaultDraft = ClothingDraft()
        hasUserEditedCategory = draft.imageData != nil || draft.category != defaultDraft.category
        hasUserEditedColor = draft.imageData != nil || draft.colorName != defaultDraft.colorName
    }

    private func imageCategorySuggestionRow(_ suggestion: ClothingImageCategorySuggestion) -> some View {
        let message = didAutoApplyImageCategory
            ? "已识别分类：\(suggestion.categoryName)，已自动填入分类"
            : "识别到分类：\(suggestion.categoryName)，可手动选择应用"

        return HStack(spacing: 10) {
            Image(systemName: suggestion.category.defaultSymbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.secondary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(message)
                    .font(.caption.weight(.medium))
                Text("可信度 \(suggestion.confidencePercent)% · \(suggestion.matchedLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !didAutoApplyImageCategory {
                Button("应用") {
                    categoryBinding.wrappedValue = suggestion.categoryName
                    didAutoApplyImageCategory = true
                }
                .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func imageColorSuggestionRow(_ suggestion: ClothingImageColorSuggestion) -> some View {
        let message = didAutoApplyImageColor
            ? "已识别主色：\(suggestion.colorName)，已自动填入颜色"
            : "识别到主色：\(suggestion.colorName)，可手动选择应用"

        return HStack(spacing: 10) {
            Circle()
                .fill(ClothingPalette.color(for: suggestion.colorName))
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(message)
                    .font(.caption.weight(.medium))
                Text("可信度 \(suggestion.confidencePercent)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if !didAutoApplyImageColor {
                Button("应用") {
                    colorNameBinding.wrappedValue = suggestion.colorName
                    didAutoApplyImageColor = true
                }
                .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }
}

struct ClothingImageImportStatus: Equatable {
    let originalByteCount: Int
    let storedByteCount: Int

    var didCompress: Bool {
        storedByteCount < originalByteCount
    }

    var message: String {
        let original = ByteCountFormatter.string(fromByteCount: Int64(originalByteCount), countStyle: .file)
        let stored = ByteCountFormatter.string(fromByteCount: Int64(storedByteCount), countStyle: .file)

        if didCompress {
            return "已优化图片：\(original) -> \(stored)"
        }
        return "已保存图片：\(stored)"
    }
}
