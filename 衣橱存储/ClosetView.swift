import SwiftUI
import SwiftData

private struct ThumbnailBackfillSource: Sendable {
    let id: UUID
    let imageData: Data
}

private struct ImageFileMigrationSource: Sendable {
    let id: UUID
    let imageData: Data
    let thumbnailData: Data?
}

private let thumbnailBackfillBatchSize = 10
private let imageFileMigrationBatchSize = 6
private let closetGridPageSize = 24
private let closetHomePreviewLimit = 6
private let closetCoveragePreviewLimit = 6

struct ClosetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var items: [WardrobeItem]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var selectedSeason = "全部季节"
    @State private var selectedFocusFilter: ClosetFocusFilter = .all
    @State private var selectedSortMode: ClosetSortMode = .recent
    @State private var showsAddSheet = false
    @State private var activeBatchImportMode: BatchClothingImportMode?
    @State private var feedback: ActionFeedbackState?
    @State private var activeOrganizationDetail: ClosetOrganizationDetail?
    @State private var showsTimelineDetail = false
    @State private var showsAllItemsDetail = false
    @State private var didStartThumbnailBackfill = false
    @State private var didRunObviousCategoryRepair = false
    @State private var cachedClosetExportText = ""
    @State private var visibleItemLimit = closetGridPageSize
    @State private var isSelectionMode = false
    @State private var selectedItemIDs = Set<UUID>()
    @State private var showsBatchDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: HomeMetrics.sectionSpacing) {
                    closetHeroSection
                    categorySection
                    clothingGridSection
                    wardrobeTimelineSection
                    closetOrganizationSection
                    closetInsightsSection
                    closetCoverageSection
                }
                .padding(.horizontal, HomeMetrics.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 148)
            }
            .background(closetBackground)
            .navigationTitle("衣橱")
            .homeInlineNavigationTitle()
            .searchable(text: $searchText, prompt: "搜索单品、颜色或分类")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if isSelectionMode {
                        Button {
                            exitSelectionMode()
                        } label: {
                            Text("完成")
                        }
                        .accessibilityLabel("完成选择")
                    } else {
                        ShareLink(
                            item: closetExportText,
                            subject: Text("衣橱清单"),
                            message: Text("来自\(AppReleaseInfo.appName)的本地衣物清单。")
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(items.isEmpty)
                        .accessibilityLabel("导出衣橱清单")

                        Button {
                            enterSelectionMode()
                        } label: {
                            Image(systemName: "checklist")
                        }
                        .buttonStyle(HomeIconButtonStyle())
                        .disabled(items.isEmpty)
                        .accessibilityLabel("选择衣物")

                        Menu {
                            Button {
                                showsAddSheet = true
                            } label: {
                                Label("添加单件", systemImage: "plus")
                            }

                            Button {
                                activeBatchImportMode = .photoLibrary
                            } label: {
                                Label("批量导入照片", systemImage: "photo.on.rectangle.angled")
                            }

                            #if canImport(UIKit)
                            Button {
                                activeBatchImportMode = .camera
                            } label: {
                                Label("批量拍照", systemImage: "camera.fill")
                            }
                            #endif
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(HomeIconButtonStyle())
                        .accessibilityLabel("添加衣物")
                    }
                }
            }
            .sheet(isPresented: $showsAddSheet) {
                AddClothingView { item in
                    feedback = ActionFeedbackState(
                        title: "已保存衣物",
                        message: "“\(item.name)”已经加入数字衣橱。"
                    )
                }
            }
            .sheet(item: $activeOrganizationDetail) { detail in
                NavigationStack {
                    ClosetOrganizationDetailView(
                        detail: detail,
                        items: organizationItems(for: detail),
                        coverageRows: organizationSnapshot.categoryRows,
                        onSelectCategory: { category in
                            selectedCategory = category
                            selectedSeason = Self.allSeasonTitle
                            selectedFocusFilter = .all
                            searchText = ""
                            selectedSortMode = .recent
                            activeOrganizationDetail = nil
                        },
                        onDeleted: { deletedName in
                            feedback = ActionFeedbackState(
                                title: "已删除衣物",
                                message: "“\(deletedName)”已从衣橱移除，相关搭配会安全保留缺失状态。",
                                systemImage: "trash"
                            )
                        }
                    )
                }
            }
            .sheet(item: $activeBatchImportMode) { mode in
                BatchClothingImportView(mode: mode) { savedCount in
                    feedback = ActionFeedbackState(
                        title: "已批量入库",
                        message: "已保存 \(savedCount) 件衣物到数字衣橱。"
                    )
                }
            }
            .sheet(isPresented: $showsAllItemsDetail) {
                NavigationStack {
                    WardrobeAllItemsDetailView(
                        items: items,
                        outfits: outfits,
                        initialCategory: selectedCategory,
                        initialSeason: selectedSeason,
                        initialFocusFilter: selectedFocusFilter,
                        initialSortMode: selectedSortMode
                    ) { deletedName in
                        feedback = ActionFeedbackState(
                            title: "已删除衣物",
                            message: "“\(deletedName)”已从衣橱移除，相关搭配会安全保留缺失状态。",
                            systemImage: "trash"
                        )
                    }
                }
            }
            .sheet(isPresented: $showsTimelineDetail) {
                NavigationStack {
                    WardrobeTimelineDetailView(items: timelineItems) { deletedName in
                        feedback = ActionFeedbackState(
                            title: "已删除衣物",
                            message: "“\(deletedName)”已从衣橱移除，相关搭配会安全保留缺失状态。",
                            systemImage: "trash"
                        )
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if let feedback {
                    ActionFeedbackBanner(
                        title: feedback.title,
                        message: feedback.message,
                        systemImage: feedback.systemImage,
                        actionTitle: feedback.actionTitle,
                        onAction: feedback.onAction,
                        onDismiss: { self.feedback = nil }
                    )
                    .padding(.horizontal, HomeMetrics.pagePadding)
                    .padding(.top, 8)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .alert(batchDeletionSummary.alertTitle, isPresented: $showsBatchDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    deleteSelectedItems()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(batchDeletionSummary.alertMessage)
            }
            .task {
                updateClosetExportText()
                repairObviousCategoryMismatchesIfNeeded()
                await migrateLegacyImagesToFilesIfNeeded()
                await backfillMissingThumbnailsIfNeeded()
            }
            .onChange(of: items) { _, _ in
                updateClosetExportText()
                pruneSelectionToExistingItems()
                resetVisibleItemLimit()
            }
            .onChange(of: searchText) { _, _ in
                resetVisibleItemLimit()
            }
            .onChange(of: selectedCategory) { _, _ in
                resetVisibleItemLimit()
            }
            .onChange(of: selectedSeason) { _, _ in
                resetVisibleItemLimit()
            }
            .onChange(of: selectedFocusFilter) { _, _ in
                resetVisibleItemLimit()
            }
            .onChange(of: selectedSortMode) { _, _ in
                resetVisibleItemLimit()
            }
        }
    }

    @ViewBuilder
    private var bottomActionBar: some View {
        if isSelectionMode {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Button {
                        toggleFilteredSelection()
                    } label: {
                        Label(filteredSelectionIsComplete ? "取消全选" : "全选筛选", systemImage: filteredSelectionIsComplete ? "minus.circle" : "checkmark.circle")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    .disabled(filteredItems.isEmpty)

                    Menu {
                        Menu {
                            ForEach(WardrobeCategory.allCases, id: \.rawValue) { category in
                                Button {
                                    applyBatchCategory(category)
                                } label: {
                                    Label(category.rawValue, systemImage: category.defaultSymbolName)
                                }
                            }
                        } label: {
                            Label("改分类", systemImage: "tag")
                        }

                        Menu {
                            ForEach(ClothingSeason.allCases, id: \.rawValue) { season in
                                Button {
                                    applyBatchSeason(season)
                                } label: {
                                    Label(season.rawValue, systemImage: "calendar")
                                }
                            }
                        } label: {
                            Label("改季节", systemImage: "leaf")
                        }

                        Divider()

                        Button {
                            applyBatchFavorite(true)
                        } label: {
                            Label("标为收藏", systemImage: "heart.fill")
                        }

                        Button {
                            applyBatchFavorite(false)
                        } label: {
                            Label("取消收藏", systemImage: "heart")
                        }
                    } label: {
                        Label("整理", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    .disabled(selectedItemIDs.isEmpty)
                    .opacity(selectedItemIDs.isEmpty ? 0.5 : 1)

                    Button(role: .destructive) {
                        showsBatchDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
                    .disabled(selectedItemIDs.isEmpty)
                    .opacity(selectedItemIDs.isEmpty ? 0.5 : 1)
                }

                HStack {
                    Text("已选 \(selectedItemIDs.count) 件")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("取消") {
                        exitSelectionMode()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.2))
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.bottom, 10)
        } else {
            HStack(spacing: 12) {
                Button {
                    showsAddSheet = true
                } label: {
                    Label("添加衣物", systemImage: "plus.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.22))
            }
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.bottom, 10)
        }
    }

    private func backfillMissingThumbnailsIfNeeded() async {
        guard !didStartThumbnailBackfill else { return }
        didStartThumbnailBackfill = true

        var attemptedItemIDs = Set<UUID>()
        while !Task.isCancelled {
            let sources = Array(
                items.lazy.compactMap { item -> ThumbnailBackfillSource? in
                    guard !attemptedItemIDs.contains(item.id),
                          item.thumbnailData == nil,
                          let imageData = item.imageData else { return nil }
                    return ThumbnailBackfillSource(id: item.id, imageData: imageData)
                }
                .prefix(thumbnailBackfillBatchSize)
            )
            guard !sources.isEmpty else { return }
            attemptedItemIDs.formUnion(sources.map(\.id))

            let generatedThumbnails = await Task.detached(priority: .utility) {
                sources.compactMap { source -> (UUID, Data)? in
                    guard let thumbnailData = ImageDataOptimizer.thumbnailJPEGData(from: source.imageData) else {
                        return nil
                    }
                    return (source.id, thumbnailData)
                }
            }.value

            guard !Task.isCancelled else { return }
            var didChange = false
            for (id, thumbnailData) in generatedThumbnails {
                guard let item = items.first(where: { $0.id == id }), item.thumbnailData == nil else { continue }
                item.thumbnailData = thumbnailData
                didChange = true
            }

            if didChange {
                try? modelContext.save()
            }

            try? await Task.sleep(for: .milliseconds(220))
        }
    }

    private func migrateLegacyImagesToFilesIfNeeded() async {
        var attemptedItemIDs = Set<UUID>()
        while !Task.isCancelled {
            let sources = Array(
                items.lazy.compactMap { item -> ImageFileMigrationSource? in
                    guard !attemptedItemIDs.contains(item.id),
                          item.imageFileName == nil,
                          let imageData = item.imageData else { return nil }
                    return ImageFileMigrationSource(id: item.id, imageData: imageData, thumbnailData: item.thumbnailData)
                }
                .prefix(imageFileMigrationBatchSize)
            )
            guard !sources.isEmpty else { return }
            attemptedItemIDs.formUnion(sources.map(\.id))

            let migratedFiles = await Task.detached(priority: .utility) {
                sources.compactMap { source -> (UUID, WardrobeStoredImageFiles)? in
                    let thumbnailData = source.thumbnailData ?? ImageDataOptimizer.thumbnailJPEGData(from: source.imageData) ?? source.imageData
                    guard let files = try? WardrobeImageFileStore.shared.storeImageSet(
                        itemID: source.id,
                        imageData: source.imageData,
                        thumbnailData: thumbnailData
                    ) else {
                        return nil
                    }
                    return (source.id, files)
                }
            }.value

            guard !Task.isCancelled else { return }
            var didChange = false
            for (id, files) in migratedFiles {
                guard let item = items.first(where: { $0.id == id }), item.imageFileName == nil else { continue }
                item.applyStoredImageFiles(files, clearInlineData: true)
                didChange = true
            }

            if didChange {
                try? modelContext.save()
                updateClosetExportText()
            }

            try? await Task.sleep(nanoseconds: 260_000_000)
        }
    }

    private func repairObviousCategoryMismatchesIfNeeded() {
        guard !didRunObviousCategoryRepair else { return }
        didRunObviousCategoryRepair = true

        var didChange = false
        for item in items {
            guard let hint = WardrobeCategory.strongNameHint(for: item.name),
                  WardrobeCategory.shouldApplyStrongNameHint(hint, over: item.category) else {
                continue
            }
            item.category = hint.rawValue
            item.imageSymbol = hint.defaultSymbolName
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
    }

    private var closetHeroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数字衣橱")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("把衣服、裤子、鞋子、包和配饰都记录进来，为 OOTD 和计划模块提供基础数据。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                closetSummaryChip(title: "全部单品", value: "\(items.count)")
                closetSummaryChip(title: "分类", value: "\(baseCategories.count)")
                closetSummaryChip(title: "未入搭配", value: "\(unusedItemsCount)")
            }

            if !items.isEmpty {
                ShareLink(
                    item: closetExportText,
                    subject: Text("衣橱清单"),
                    message: Text("来自\(AppReleaseInfo.appName)的本地衣物清单。")
                ) {
                    Label("导出衣橱清单", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
            }
        }
    }

    @ViewBuilder
    private var wardrobeTimelineSection: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("入库时间线")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Button {
                        showsTimelineDetail = true
                        AppHaptics.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Text("查看全部")
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    timelineSummaryChip(title: "今日新增", value: "\(todayTimelineItemCount)", detail: "件")
                    timelineSummaryChip(title: "最近批次", value: latestBatchCountText, detail: latestBatchSubtitle)
                }

                VStack(spacing: 8) {
                    ForEach(timelineItems.prefix(3), id: \.id) { item in
                        NavigationLink {
                            ClothingDetailView(item: item) { deletedName in
                                feedback = ActionFeedbackState(
                                    title: "已删除衣物",
                                    message: "“\(deletedName)”已从衣橱移除，相关搭配会安全保留缺失状态。",
                                    systemImage: "trash"
                                )
                            }
                        } label: {
                            timelineItemRow(item, isCompact: true)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                    }
                }
            }
            .padding(14)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    @ViewBuilder
    private var closetOrganizationSection: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                closetSectionHeader(title: "整理建议", subtitle: "自动扫描")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    closetInsightCard(
                        title: "未入搭配",
                        value: "\(organizationSnapshot.unusedItemCount)",
                        detail: organizationSnapshot.unusedItemCount == 0 ? "所有单品都已被搭配使用" : "适合继续组合 OOTD",
                        systemImage: "link.badge.plus"
                    ) {
                        activeOrganizationDetail = .unused
                    }

                    closetInsightCard(
                        title: "缺少图片",
                        value: "\(organizationSnapshot.missingImageCount)",
                        detail: organizationSnapshot.missingImageCount == 0 ? "图片记录完整" : "可优先补拍照片",
                        systemImage: "photo.badge.exclamationmark"
                    ) {
                        activeOrganizationDetail = .missingImage
                    }

                    closetInsightCard(
                        title: "待补资料",
                        value: "\(organizationSnapshot.detailGapCount)",
                        detail: organizationSnapshot.detailGapCount == 0 ? "基础资料完整" : "缺少图片、标签、品牌或尺码",
                        systemImage: "checklist"
                    ) {
                        activeOrganizationDetail = .needsDetails
                    }

                    closetInsightCard(
                        title: "分类覆盖",
                        value: organizationSnapshot.coverageText,
                        detail: missingCategorySummary,
                        systemImage: "square.grid.2x2"
                    ) {
                        activeOrganizationDetail = .categoryCoverage
                    }

                    closetInsightCard(
                        title: "收藏单品",
                        value: "\(organizationSnapshot.favoriteCount)",
                        detail: "常穿单品可快速筛出",
                        systemImage: "heart"
                    ) {
                        activeOrganizationDetail = .favorites
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var closetCoverageSection: some View {
        if !items.isEmpty {
            let coveredRows = coveredCategoryRows
            let previewRows = Array(coveredRows.prefix(closetCoveragePreviewLimit))

            VStack(alignment: .leading, spacing: 14) {
                closetSectionHeader(
                    title: "分类覆盖",
                    subtitle: coveredRows.isEmpty ? "待录入" : "\(coveredRows.count) 类已录入",
                    actionTitle: "查看全部"
                ) {
                    activeOrganizationDetail = .categoryCoverage
                    AppHaptics.selection()
                }

                VStack(alignment: .leading, spacing: 10) {
                    if previewRows.isEmpty {
                        Text("先添加几件常穿衣物，衣序会按已有分类生成覆盖概览。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                    } else {
                        ForEach(previewRows) { row in
                            closetCoverageRow(row)
                        }

                        if coveredRows.count > previewRows.count || !organizationSnapshot.missingCoreCategories.isEmpty {
                            Button {
                                activeOrganizationDetail = .categoryCoverage
                                AppHaptics.selection()
                            } label: {
                                Label(
                                    organizationSnapshot.missingCoreCategories.isEmpty ? "查看全部分类覆盖" : "查看缺失核心分类",
                                    systemImage: "square.grid.2x2"
                                )
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    closetSectionHeader(title: "整理任务", subtitle: organizationSnapshot.tasks.isEmpty ? "已完成" : "\(organizationSnapshot.tasks.count) 项")

                    if organizationSnapshot.tasks.isEmpty {
                        Text("当前没有高优先级整理任务。继续保持定期备份和照片压缩就很好。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                    } else {
                        ForEach(organizationSnapshot.tasks) { task in
                            Button {
                                handleOrganizationTask(task)
                            } label: {
                                closetTaskRow(task)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var closetInsightsSection: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                closetSectionHeader(title: "衣橱报告", subtitle: "结构与价值")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    closetInsightCard(
                        title: "已记录金额",
                        value: insightsSnapshot.totalPurchaseValueText,
                        detail: "\(insightsSnapshot.pricedCoverageText) 件填写了价格",
                        systemImage: "yensign.circle"
                    )

                    closetInsightCard(
                        title: "平均价格",
                        value: insightsSnapshot.averagePurchaseValueText,
                        detail: "仅统计已填写价格的单品",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )

                    closetInsightCard(
                        title: "常见品牌",
                        value: insightsSnapshot.topBrandText,
                        detail: insightsSnapshot.brandRows.isEmpty ? "还没有品牌记录" : "用于后续品牌偏好分析",
                        systemImage: "tag"
                    )

                    closetInsightCard(
                        title: "资料完整度",
                        value: insightsSnapshot.detailCompletionText,
                        detail: "包含图片、风格标签、品牌和尺码",
                        systemImage: "checkmark.seal"
                    )
                }

                closetDistributionGroup(title: "颜色分布", rows: Array(insightsSnapshot.colorRows.prefix(5)))
                closetDistributionGroup(title: "季节分布", rows: Array(insightsSnapshot.seasonRows.prefix(5)))
                closetDistributionGroup(title: "品牌分布", rows: Array(insightsSnapshot.brandRows.prefix(5)), emptyText: "还没有填写品牌。")
                closetDistributionGroup(title: "尺码分布", rows: Array(insightsSnapshot.sizeRows.prefix(5)), emptyText: "还没有填写尺码。")
                closetDistributionGroup(title: "购买渠道", rows: Array(insightsSnapshot.purchaseChannelRows.prefix(5)), emptyText: "还没有填写购买渠道。")
            }
        }
    }

    private var categorySection: some View {
        return VStack(alignment: .leading, spacing: 14) {
            closetFilterHeader

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                            AppHaptics.selection()
                        } label: {
                            Text(category)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(selectedCategory == category ? .primary : .secondary)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .glassCard(
                            cornerRadius: HomeMetrics.pillRadius,
                            tint: selectedCategory == category ? Color.white.opacity(0.28) : Color.white.opacity(0.14)
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(seasonFilters, id: \.self) { season in
                        Button {
                            selectedSeason = season
                            AppHaptics.selection()
                        } label: {
                            Text(season)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(selectedSeason == season ? .primary : .secondary)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: selectedSeason == season ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ClosetFocusFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFocusFilter = filter
                            AppHaptics.selection()
                        } label: {
                            Label(filter.title, systemImage: filter.systemImage)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: selectedFocusFilter == filter ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            Picker("排序", selection: $selectedSortMode) {
                ForEach(ClosetSortMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
        }
    }

    private var clothingGridSection: some View {
        let currentFilteredItems = filteredItems
        let currentPreviewLimit = isSelectionMode ? visibleItemLimit : closetHomePreviewLimit
        let currentVisibleItems = currentFilteredItems.prefix(currentPreviewLimit)
        let remainingCount = max(currentFilteredItems.count - currentVisibleItems.count, 0)

        return VStack(alignment: .leading, spacing: 14) {
            closetSectionHeader(
                title: selectedCategory == "全部" ? "最近单品" : selectedCategory,
                subtitle: "\(currentFilteredItems.count) 件",
                actionTitle: currentFilteredItems.isEmpty ? nil : "查看全部"
            ) {
                showsAllItemsDetail = true
                AppHaptics.selection()
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                if currentFilteredItems.isEmpty {
                    emptyClosetCard
                        .gridCellColumns(2)
                } else {
                    ForEach(currentVisibleItems, id: \.id) { item in
                        if isSelectionMode {
                            Button {
                                toggleSelection(for: item)
                            } label: {
                                selectableWardrobeItemCard(item)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .accessibilityLabel(selectionAccessibilityLabel(for: item))
                        } else {
                            NavigationLink {
                                ClothingDetailView(item: item) { deletedName in
                                    feedback = ActionFeedbackState(
                                        title: "已删除衣物",
                                        message: "“\(deletedName)”已从衣橱移除，相关搭配会安全保留缺失状态。",
                                        systemImage: "trash"
                                    )
                                }
                            } label: {
                                WardrobeItemCard(item: item, emphasis: .grid)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .contextMenu {
                                Button {
                                    enterSelectionMode(selecting: item)
                                } label: {
                                    Label("选择", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }

                    if currentVisibleItems.count < currentFilteredItems.count {
                        Button {
                            if isSelectionMode {
                                expandVisibleItemLimit()
                            } else {
                                showsAllItemsDetail = true
                            }
                            AppHaptics.selection()
                        } label: {
                            Label(
                                isSelectionMode ? "继续加载 \(min(closetGridPageSize, remainingCount)) 件" : "查看全部 \(currentFilteredItems.count) 件",
                                systemImage: isSelectionMode ? "arrow.down.circle" : "square.grid.2x2"
                            )
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                        .gridCellColumns(2)
                        .onAppear {
                            guard isSelectionMode else { return }
                            expandVisibleItemLimit()
                        }
                    }
                }
            }
        }
    }

    private func selectableWardrobeItemCard(_ item: WardrobeItem) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)
        return WardrobeItemCard(item: item, emphasis: .grid)
            .overlay(alignment: .topTrailing) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.9))
                    .padding(7)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.black.opacity(0.22))
                    )
                    .padding(10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: HomeMetrics.secondaryRadius, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.82) : Color.clear, lineWidth: 2)
            }
    }

    private var filteredItems: [WardrobeItem] {
        let usageCounts = outfitUsageCountsByItemID
        let filtered = items.filter { item in
            let matchesCategory: Bool
            if selectedCategory == "全部" {
                matchesCategory = true
            } else if selectedCategory == "收藏" {
                matchesCategory = item.isFavorite
            } else {
                matchesCategory = item.category == selectedCategory
            }
            let matchesSeason = selectedSeason == Self.allSeasonTitle || item.season == selectedSeason
            let matchesFocus: Bool
            switch selectedFocusFilter {
            case .all:
                matchesFocus = true
            case .unused:
                matchesFocus = outfitUsageCount(for: item, usageCounts: usageCounts) == 0
            case .missingImage:
                matchesFocus = !item.hasPhoto
            case .needsDetails:
                matchesFocus = itemNeedsDetails(item)
            }
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = keyword.isEmpty
            || item.searchableFields.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesSeason && matchesFocus && matchesSearch
        }

        return sortedItems(filtered, usageCounts: usageCounts)
    }

    private var categories: [String] {
        ["全部", "收藏"] + baseCategories
    }

    private var seasonFilters: [String] {
        [Self.allSeasonTitle] + Array(Set(items.map(\.season))).sorted()
    }

    private var baseCategories: [String] {
        WardrobeCategory.orderedRawValues(from: items.map(\.category))
    }

    private var organizationSnapshot: ClosetOrganizationSnapshot {
        ClosetOrganizationSnapshot.make(items: items, outfits: outfits)
    }

    private var timelineItems: [WardrobeItem] {
        items
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    private var coveredCategoryRows: [ClosetCategoryCoverage] {
        organizationSnapshot.categoryRows.filter { $0.count > 0 }
    }

    private var todayTimelineItemCount: Int {
        let calendar = Calendar.current
        return items.filter { calendar.isDateInToday($0.createdAt) }.count
    }

    private var latestBatchItems: [WardrobeItem] {
        guard let latestBatchID = timelineItems.first?.importBatchID else {
            return timelineItems.first.map { [$0] } ?? []
        }

        return timelineItems
            .filter { $0.importBatchID == latestBatchID }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    private var latestBatchCountText: String {
        "\(max(latestBatchItems.count, 0))"
    }

    private var latestBatchSubtitle: String {
        latestBatchItems.count > 1 ? "本次导入" : "单件入库"
    }

    private var insightsSnapshot: WardrobeInsightsSnapshot {
        WardrobeInsightsSnapshot.make(items: items)
    }

    private var unusedItemsCount: Int {
        organizationSnapshot.unusedItemCount
    }

    private var missingCategorySummary: String {
        let missing = organizationSnapshot.missingCoreCategories
        if missing.isEmpty {
            return "核心分类已经覆盖"
        }
        return "缺少 \(missing.prefix(3).joined(separator: "、"))"
    }

    private var closetExportText: String {
        if cachedClosetExportText.isEmpty {
            return "衣橱清单\n正在准备导出内容。"
        }
        return cachedClosetExportText
    }

    private func updateClosetExportText() {
        cachedClosetExportText = WardrobeExporter.plainText(from: items)
    }

    private var closetBackground: some View {
        AppAdaptiveBackground()
    }

    private var selectedItems: [WardrobeItem] {
        items.filter { selectedItemIDs.contains($0.id) }
    }

    private var filteredSelectionIsComplete: Bool {
        let currentFilteredItems = filteredItems
        guard !currentFilteredItems.isEmpty else { return false }
        let filteredItemIDs = Set(currentFilteredItems.map(\.id))
        return filteredItemIDs.isSubset(of: selectedItemIDs)
    }

    private var batchDeletionSummary: WardrobeBatchDeletionSummary {
        WardrobeBatchDeletionSummary.make(
            itemsToDelete: selectedItems,
            outfits: outfits,
            plans: plans
        )
    }

    private var closetFilterHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("筛选与排序")
                .font(.title3.weight(.semibold))
            Spacer()
            Button {
                startQuickOrganize()
            } label: {
                Label("快速整理", systemImage: "wand.and.stars")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(items.isEmpty ? Color.secondary : Color.primary.opacity(0.82))
            }
            .buttonStyle(HomePressableButtonStyle())
            .disabled(items.isEmpty)
            .accessibilityLabel("快速整理衣橱")
        }
    }

    private func closetSectionHeader(
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            if let actionTitle, let action {
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(HomePressableButtonStyle())
            } else {
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func closetSummaryChip(title: String, value: String) -> some View {
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

    private func timelineSummaryChip(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func timelineItemRow(_ item: WardrobeItem, isCompact: Bool) -> some View {
        HStack(spacing: 10) {
            WardrobeItemImageView(item: item, cornerRadius: 14, symbolFont: .subheadline.weight(.semibold))
                .frame(width: isCompact ? 48 : 64, height: isCompact ? 48 : 64)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font((isCompact ? Font.subheadline : Font.headline).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.category)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                }

                Text("\(timelineDateText(item.createdAt)) · \(item.colorName) · \(item.season)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(isCompact ? 10 : 12)
        .homeCardSurface(weight: isCompact ? .tertiary : .secondary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func timelineDateText(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "zh_Hans_CN"))
                .year()
                .month()
                .day()
                .hour()
                .minute()
        )
    }

    @ViewBuilder
    private func closetInsightCard(
        title: String,
        value: String,
        detail: String,
        systemImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        if let action {
            Button(action: action) {
                closetInsightCardContent(title: title, value: value, detail: detail, systemImage: systemImage)
            }
            .buttonStyle(HomePressableButtonStyle())
        } else {
            closetInsightCardContent(title: title, value: value, detail: detail, systemImage: systemImage)
        }
    }

    private func closetInsightCardContent(
        title: String,
        value: String,
        detail: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.82))
                Spacer()
                Text(value)
                    .font(.headline.monospacedDigit().weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func closetCoverageRow(_ row: ClosetCategoryCoverage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.category)
                    .font(.subheadline.weight(.semibold))
                if row.isCore {
                    Text("核心")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                }
                Spacer()
                Text("\(row.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(row.count), total: Double(organizationSnapshot.maxCategoryCount))
                .tint(row.count == 0 ? Color.secondary : Color.primary.opacity(0.72))
        }
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func closetDistributionGroup(
        title: String,
        rows: [WardrobeInsightRank],
        emptyText: String = "暂无可统计数据。"
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            closetSectionHeader(title: title, subtitle: rows.isEmpty ? "待补充" : "\(rows.count) 项")

            if rows.isEmpty {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
            } else {
                ForEach(rows) { row in
                    closetDistributionRow(row)
                }
            }
        }
    }

    private func closetDistributionRow(_ row: WardrobeInsightRank) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(row.count) 件 · \(row.shareText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: row.share)
                .tint(Color.primary.opacity(0.72))
        }
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func closetTaskRow(_ task: ClosetOrganizationTask) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: task.systemImage)
                .font(.headline)
                .frame(width: 34, height: 34)
                .homeCardSurface(weight: .tertiary, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                Text(task.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
        .padding(16)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var emptyClosetCard: some View {
        WardrobeEmptyStateView(
            title: items.isEmpty ? "还没有衣物" : "没有匹配的衣物",
            message: items.isEmpty ? "先添加第一件衣物，衣橱、OOTD 和计划都会从这里读取。" : "换个关键词，或清空筛选查看完整衣物库。",
            systemImage: items.isEmpty ? "tshirt.fill" : "line.3.horizontal.decrease.circle",
            actionTitle: items.isEmpty ? "添加衣物" : "清空筛选",
            actionSystemImage: items.isEmpty ? "plus.viewfinder" : "line.3.horizontal.decrease.circle"
        ) {
                if items.isEmpty {
                    showsAddSheet = true
                } else {
                    clearClosetFilters()
                }
        }
    }

    private func startQuickOrganize() {
        selectedCategory = "全部"
        selectedSeason = Self.allSeasonTitle
        selectedFocusFilter = .all
        searchText = ""
        selectedSortMode = .recent
        resetVisibleItemLimit()
        AppHaptics.selection()

        if organizationSnapshot.detailGapCount > 0 {
            activeOrganizationDetail = .needsDetails
        } else if organizationSnapshot.missingImageCount > 0 {
            activeOrganizationDetail = .missingImage
        } else if organizationSnapshot.unusedItemCount > 0 {
            activeOrganizationDetail = .unused
        } else if !organizationSnapshot.missingCoreCategories.isEmpty {
            activeOrganizationDetail = .categoryCoverage
        } else {
            feedback = ActionFeedbackState(
                title: "衣橱状态良好",
                message: "当前没有明显待整理项目，可以继续添加新衣物或创建 OOTD。",
                systemImage: "checkmark.seal.fill"
            )
        }
    }

    private func resetVisibleItemLimit() {
        visibleItemLimit = closetGridPageSize
    }

    private func expandVisibleItemLimit() {
        let totalCount = filteredItems.count
        guard visibleItemLimit < totalCount else { return }
        visibleItemLimit = min(totalCount, visibleItemLimit + closetGridPageSize)
    }

    private func organizationItems(for detail: ClosetOrganizationDetail) -> [WardrobeItem] {
        switch detail {
        case .unused:
            sortedItems(items.filter { outfitUsageCount(for: $0) == 0 })
        case .missingImage:
            sortedItems(items.filter { !$0.hasPhoto })
        case .needsDetails:
            sortedItems(items.filter(itemNeedsDetails))
        case .categoryCoverage:
            []
        case .favorites:
            sortedItems(items.filter(\.isFavorite))
        }
    }

    private func handleOrganizationTask(_ task: ClosetOrganizationTask) {
        switch task.kind {
        case .addClothing:
            showsAddSheet = true
        case .showNeedsDetails:
            activeOrganizationDetail = .needsDetails
        case .showUnused:
            activeOrganizationDetail = .unused
        }
    }

    private func clearClosetFilters() {
        selectedCategory = "全部"
        selectedSeason = Self.allSeasonTitle
        selectedFocusFilter = .all
        searchText = ""
        selectedSortMode = .recent
        AppHaptics.selection()
    }

    private func enterSelectionMode(selecting item: WardrobeItem? = nil) {
        isSelectionMode = true
        if let item {
            selectedItemIDs.insert(item.id)
        }
        AppHaptics.selection()
    }

    private func exitSelectionMode() {
        selectedItemIDs.removeAll()
        isSelectionMode = false
        AppHaptics.selection()
    }

    private func toggleSelection(for item: WardrobeItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
        AppHaptics.selection()
    }

    private func toggleFilteredSelection() {
        let filteredItemIDs = Set(filteredItems.map(\.id))
        guard !filteredItemIDs.isEmpty else { return }

        if filteredItemIDs.isSubset(of: selectedItemIDs) {
            selectedItemIDs.subtract(filteredItemIDs)
        } else {
            selectedItemIDs.formUnion(filteredItemIDs)
        }
        AppHaptics.selection()
    }

    private func pruneSelectionToExistingItems() {
        let existingIDs = Set(items.map(\.id))
        selectedItemIDs.formIntersection(existingIDs)
        if isSelectionMode, items.isEmpty {
            selectedItemIDs.removeAll()
            isSelectionMode = false
        }
    }

    private func deleteSelectedItems() {
        let itemsToDelete = selectedItems
        guard !itemsToDelete.isEmpty else { return }
        let imageFileNamesToRemove = itemsToDelete.flatMap { item in
            [item.imageFileName, item.thumbnailFileName].compactMap { $0 }
        }

        for outfit in outfits {
            for item in itemsToDelete where outfitUsesItem(outfit, item: item) {
                outfit.removeReferences(to: item)
            }
        }

        for item in itemsToDelete {
            modelContext.delete(item)
        }

        do {
            try modelContext.save()
            for fileName in imageFileNamesToRemove {
                WardrobeImageFileStore.shared.remove(fileName: fileName)
            }
            let deletedCount = itemsToDelete.count
            selectedItemIDs.removeAll()
            isSelectionMode = false
            resetVisibleItemLimit()
            AppHaptics.warning()
            feedback = ActionFeedbackState(
                title: "已批量删除",
                message: "已从衣橱移除 \(deletedCount) 件衣物，相关 OOTD 和计划已安全保留。",
                systemImage: "trash"
            )
        } catch {
            modelContext.rollback()
            feedback = ActionFeedbackState(
                title: "批量删除失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func applyBatchCategory(_ category: WardrobeCategory) {
        applyBatchUpdate(
            successTitle: "已批量改分类",
            successMessage: "已将 \(selectedItemIDs.count) 件衣物改为\(category.rawValue)。",
            failureTitle: "批量改分类失败"
        ) { item, updatedAt in
            item.category = category.rawValue
            item.imageSymbol = category.defaultSymbolName
            item.updatedAt = updatedAt
        }
    }

    private func applyBatchSeason(_ season: ClothingSeason) {
        applyBatchUpdate(
            successTitle: "已批量改季节",
            successMessage: "已将 \(selectedItemIDs.count) 件衣物改为\(season.rawValue)。",
            failureTitle: "批量改季节失败"
        ) { item, updatedAt in
            item.season = season.rawValue
            item.updatedAt = updatedAt
        }
    }

    private func applyBatchFavorite(_ isFavorite: Bool) {
        applyBatchUpdate(
            successTitle: isFavorite ? "已批量收藏" : "已取消收藏",
            successMessage: isFavorite ? "已把 \(selectedItemIDs.count) 件衣物标为收藏。" : "已取消 \(selectedItemIDs.count) 件衣物的收藏状态。",
            failureTitle: "批量更新收藏失败"
        ) { item, updatedAt in
            item.isFavorite = isFavorite
            item.updatedAt = updatedAt
        }
    }

    private func applyBatchUpdate(
        successTitle: String,
        successMessage: String,
        failureTitle: String,
        update: (WardrobeItem, Date) -> Void
    ) {
        let itemsToUpdate = selectedItems
        guard !itemsToUpdate.isEmpty else { return }

        let updatedAt = Date.now
        for item in itemsToUpdate {
            update(item, updatedAt)
        }

        do {
            try modelContext.save()
            updateClosetExportText()
            resetVisibleItemLimit()
            AppHaptics.selection()
            feedback = ActionFeedbackState(
                title: successTitle,
                message: successMessage,
                systemImage: "checkmark.circle.fill"
            )
        } catch {
            modelContext.rollback()
            feedback = ActionFeedbackState(
                title: failureTitle,
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func selectionAccessibilityLabel(for item: WardrobeItem) -> String {
        selectedItemIDs.contains(item.id) ? "取消选择\(item.name)" : "选择\(item.name)"
    }

    private var outfitUsageCountsByItemID: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for outfit in outfits {
            for item in outfit.orderedItems {
                counts[item.id, default: 0] += 1
            }
        }
        return counts
    }

    private func sortedItems(_ items: [WardrobeItem], usageCounts: [UUID: Int]? = nil) -> [WardrobeItem] {
        let usageCounts = usageCounts ?? outfitUsageCountsByItemID
        return items.sorted { lhs, rhs in
            switch selectedSortMode {
            case .recent:
                if lhs.lastModifiedAt == rhs.lastModifiedAt {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhs.lastModifiedAt > rhs.lastModifiedAt
            case .name:
                return isOrdered(lhs.name, before: rhs.name)
            case .category:
                if lhs.category == rhs.category {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return isOrderedCategory(lhs.category, before: rhs.category)
            case .season:
                if lhs.season == rhs.season {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return isOrdered(lhs.season, before: rhs.season)
            case .usage:
                let lhsUsage = outfitUsageCount(for: lhs, usageCounts: usageCounts)
                let rhsUsage = outfitUsageCount(for: rhs, usageCounts: usageCounts)
                if lhsUsage == rhsUsage {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhsUsage < rhsUsage
            }
        }
    }

    private func outfitUsageCount(for item: WardrobeItem, usageCounts: [UUID: Int]? = nil) -> Int {
        if let usageCounts {
            return usageCounts[item.id, default: 0]
        }
        return outfits.filter { outfitUsesItem($0, item: item) }.count
    }

    private func itemNeedsDetails(_ item: WardrobeItem) -> Bool {
        item.needsDetailCompletion
    }

    private func outfitUsesItem(_ outfit: OOTDOutfit, item: WardrobeItem) -> Bool {
        if outfit.topItem?.id == item.id { return true }
        if outfit.bottomItem?.id == item.id { return true }
        if outfit.outerwearItem?.id == item.id { return true }
        if outfit.shoesItem?.id == item.id { return true }
        if outfit.bagItem?.id == item.id { return true }
        if outfit.accessoryItem?.id == item.id { return true }
        return false
    }

    private func isOrdered(_ lhs: String, before rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private func isOrderedCategory(_ lhs: String, before rhs: String) -> Bool {
        let lhsOrder = WardrobeCategory(rawValue: lhs)?.filterOrder ?? Int.max
        let rhsOrder = WardrobeCategory(rawValue: rhs)?.filterOrder ?? Int.max
        if lhsOrder == rhsOrder {
            return isOrdered(lhs, before: rhs)
        }
        return lhsOrder < rhsOrder
    }
}

fileprivate extension ClosetView {
    static let allSeasonTitle = "全部季节"

    enum ClosetFocusFilter: CaseIterable {
        case all
        case unused
        case missingImage
        case needsDetails

        var title: String {
            switch self {
            case .all:
                "全部状态"
            case .unused:
                "未入搭配"
            case .missingImage:
                "缺图片"
            case .needsDetails:
                "待补资料"
            }
        }

        var systemImage: String {
            switch self {
            case .all:
                "square.grid.2x2"
            case .unused:
                "link.badge.plus"
            case .missingImage:
                "photo.badge.exclamationmark"
            case .needsDetails:
                "checklist"
            }
        }
    }

    enum ClosetOrganizationDetail: String, Identifiable {
        case unused
        case missingImage
        case needsDetails
        case categoryCoverage
        case favorites

        var id: String { rawValue }

        var title: String {
            switch self {
            case .unused:
                "未入搭配"
            case .missingImage:
                "缺少图片"
            case .needsDetails:
                "待补资料"
            case .categoryCoverage:
                "分类覆盖"
            case .favorites:
                "收藏单品"
            }
        }

        var subtitle: String {
            switch self {
            case .unused:
                "这些单品还没有加入任何 OOTD。"
            case .missingImage:
                "进入详情后可补拍或替换图片。"
            case .needsDetails:
                "优先补图片、标签、品牌和尺码。"
            case .categoryCoverage:
                "查看核心分类是否已经覆盖。"
            case .favorites:
                "常穿单品会在推荐里获得更高权重。"
            }
        }

        var emptyText: String {
            switch self {
            case .unused:
                "当前所有单品都已经加入过 OOTD。"
            case .missingImage:
                "当前没有缺少图片的单品。"
            case .needsDetails:
                "当前没有明显待补资料的单品。"
            case .categoryCoverage:
                "暂无分类覆盖数据。"
            case .favorites:
                "还没有收藏单品。进入衣物详情可以标记常穿。"
            }
        }
    }

    enum ClosetSortMode: CaseIterable {
        case recent
        case name
        case category
        case season
        case usage

        var title: String {
            switch self {
            case .recent:
                "最近更新"
            case .name:
                "名称"
            case .category:
                "分类"
            case .season:
                "季节"
            case .usage:
                "使用少优先"
            }
        }
    }
}

private struct WardrobeAllItemsDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [WardrobeItem]
    let outfits: [OOTDOutfit]
    let onDeleted: (String) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: String
    @State private var selectedSeason: String
    @State private var selectedFocusFilter: ClosetView.ClosetFocusFilter
    @State private var selectedSortMode: ClosetView.ClosetSortMode
    @State private var visibleItemLimit = closetGridPageSize

    init(
        items: [WardrobeItem],
        outfits: [OOTDOutfit],
        initialCategory: String,
        initialSeason: String,
        initialFocusFilter: ClosetView.ClosetFocusFilter,
        initialSortMode: ClosetView.ClosetSortMode,
        onDeleted: @escaping (String) -> Void
    ) {
        self.items = items
        self.outfits = outfits
        self.onDeleted = onDeleted
        _selectedCategory = State(initialValue: initialCategory)
        _selectedSeason = State(initialValue: initialSeason)
        _selectedFocusFilter = State(initialValue: initialFocusFilter)
        _selectedSortMode = State(initialValue: initialSortMode)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                filterSection
                itemGridSection
            }
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 48)
        }
        .background(AppAdaptiveBackground())
        .navigationTitle("全部单品")
        .homeInlineNavigationTitle()
        .searchable(text: $searchText, prompt: "搜索单品、颜色或分类")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") {
                    dismiss()
                }
            }
        }
        .onChange(of: searchText) { _, _ in resetVisibleItemLimit() }
        .onChange(of: selectedCategory) { _, _ in resetVisibleItemLimit() }
        .onChange(of: selectedSeason) { _, _ in resetVisibleItemLimit() }
        .onChange(of: selectedFocusFilter) { _, _ in resetVisibleItemLimit() }
        .onChange(of: selectedSortMode) { _, _ in resetVisibleItemLimit() }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("全部单品")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("这里承载完整衣橱管理。一级页只放预览，300 件以上也不会把首页撑长。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                summaryPill(title: "总数", value: "\(items.count)", detail: "件")
                summaryPill(title: "当前结果", value: "\(filteredItems.count)", detail: "件")
                summaryPill(title: "已收藏", value: "\(items.filter(\.isFavorite).count)", detail: "件")
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                            AppHaptics.selection()
                        } label: {
                            Text(category)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .foregroundStyle(selectedCategory == category ? .primary : .secondary)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .glassCard(
                            cornerRadius: HomeMetrics.pillRadius,
                            tint: selectedCategory == category ? Color.white.opacity(0.28) : Color.white.opacity(0.14)
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(seasonFilters, id: \.self) { season in
                        Button {
                            selectedSeason = season
                            AppHaptics.selection()
                        } label: {
                            Text(season)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: selectedSeason == season ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                Menu {
                    ForEach(ClosetView.ClosetFocusFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFocusFilter = filter
                        } label: {
                            Label(filter.title, systemImage: filter.systemImage)
                        }
                    }
                } label: {
                    Label(selectedFocusFilter.title, systemImage: selectedFocusFilter.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)

                Menu {
                    ForEach(ClosetView.ClosetSortMode.allCases, id: \.self) { mode in
                        Button {
                            selectedSortMode = mode
                        } label: {
                            Text(mode.title)
                        }
                    }
                } label: {
                    Label(selectedSortMode.title, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
            }
        }
    }

    private var itemGridSection: some View {
        let currentFilteredItems = filteredItems
        let visibleItems = currentFilteredItems.prefix(visibleItemLimit)

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 14
        ) {
            if currentFilteredItems.isEmpty {
                WardrobeEmptyStateView(
                    title: items.isEmpty ? "还没有衣物" : "没有匹配的衣物",
                    message: items.isEmpty ? "先添加第一件衣物，再回到这里管理完整衣橱。" : "换个关键词，或清空筛选查看完整衣物库。",
                    systemImage: items.isEmpty ? "tshirt.fill" : "line.3.horizontal.decrease.circle",
                    actionTitle: "清空筛选",
                    actionSystemImage: "line.3.horizontal.decrease.circle"
                ) {
                    clearFilters()
                }
                .gridCellColumns(2)
            } else {
                ForEach(visibleItems, id: \.id) { item in
                    NavigationLink {
                        ClothingDetailView(item: item, onDeleted: onDeleted)
                    } label: {
                        WardrobeItemCard(item: item, emphasis: .grid)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }

                if visibleItems.count < currentFilteredItems.count {
                    Button {
                        expandVisibleItemLimit()
                        AppHaptics.selection()
                    } label: {
                        Label(
                            "继续加载 \(min(closetGridPageSize, currentFilteredItems.count - visibleItems.count)) 件",
                            systemImage: "arrow.down.circle"
                        )
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                    .gridCellColumns(2)
                }
            }
        }
    }

    private var filteredItems: [WardrobeItem] {
        let usageCounts = outfitUsageCountsByItemID
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = items.filter { item in
            let matchesCategory: Bool
            if selectedCategory == "全部" {
                matchesCategory = true
            } else if selectedCategory == "收藏" {
                matchesCategory = item.isFavorite
            } else {
                matchesCategory = item.category == selectedCategory
            }

            let matchesSeason = selectedSeason == ClosetView.allSeasonTitle || item.season == selectedSeason
            let matchesFocus: Bool
            switch selectedFocusFilter {
            case .all:
                matchesFocus = true
            case .unused:
                matchesFocus = outfitUsageCount(for: item, usageCounts: usageCounts) == 0
            case .missingImage:
                matchesFocus = !item.hasPhoto
            case .needsDetails:
                matchesFocus = item.needsDetailCompletion
            }

            let matchesSearch = keyword.isEmpty
            || item.searchableFields.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesSeason && matchesFocus && matchesSearch
        }

        return sortedItems(filtered, usageCounts: usageCounts)
    }

    private var categories: [String] {
        ["全部", "收藏"] + WardrobeCategory.orderedRawValues(from: items.map(\.category))
    }

    private var seasonFilters: [String] {
        [ClosetView.allSeasonTitle] + Array(Set(items.map(\.season))).sorted()
    }

    private var outfitUsageCountsByItemID: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for outfit in outfits {
            for item in outfit.orderedItems {
                counts[item.id, default: 0] += 1
            }
        }
        return counts
    }

    private func sortedItems(_ items: [WardrobeItem], usageCounts: [UUID: Int]) -> [WardrobeItem] {
        items.sorted { lhs, rhs in
            switch selectedSortMode {
            case .recent:
                if lhs.lastModifiedAt == rhs.lastModifiedAt {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhs.lastModifiedAt > rhs.lastModifiedAt
            case .name:
                return isOrdered(lhs.name, before: rhs.name)
            case .category:
                if lhs.category == rhs.category {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return isOrderedCategory(lhs.category, before: rhs.category)
            case .season:
                if lhs.season == rhs.season {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return isOrdered(lhs.season, before: rhs.season)
            case .usage:
                let lhsUsage = outfitUsageCount(for: lhs, usageCounts: usageCounts)
                let rhsUsage = outfitUsageCount(for: rhs, usageCounts: usageCounts)
                if lhsUsage == rhsUsage {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhsUsage < rhsUsage
            }
        }
    }

    private func outfitUsageCount(for item: WardrobeItem, usageCounts: [UUID: Int]) -> Int {
        usageCounts[item.id, default: 0]
    }

    private func resetVisibleItemLimit() {
        visibleItemLimit = closetGridPageSize
    }

    private func expandVisibleItemLimit() {
        guard visibleItemLimit < filteredItems.count else { return }
        visibleItemLimit = min(filteredItems.count, visibleItemLimit + closetGridPageSize)
    }

    private func clearFilters() {
        selectedCategory = "全部"
        selectedSeason = ClosetView.allSeasonTitle
        selectedFocusFilter = .all
        searchText = ""
        selectedSortMode = .recent
        AppHaptics.selection()
    }

    private func summaryPill(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func isOrdered(_ lhs: String, before rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private func isOrderedCategory(_ lhs: String, before rhs: String) -> Bool {
        let lhsOrder = WardrobeCategory(rawValue: lhs)?.filterOrder ?? Int.max
        let rhsOrder = WardrobeCategory(rawValue: rhs)?.filterOrder ?? Int.max
        if lhsOrder == rhsOrder {
            return isOrdered(lhs, before: rhs)
        }
        return lhsOrder < rhsOrder
    }
}

private struct ClosetOrganizationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let detail: ClosetView.ClosetOrganizationDetail
    let items: [WardrobeItem]
    let coverageRows: [ClosetCategoryCoverage]
    let onSelectCategory: (String) -> Void
    let onDeleted: (String) -> Void
    @State private var showsAllCoverageRows = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(detail.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if detail == .categoryCoverage {
                    coverageSection
                } else if items.isEmpty {
                    emptyDetailCard
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(items, id: \.id) { item in
                            NavigationLink {
                                ClothingDetailView(item: item, onDeleted: onDeleted)
                            } label: {
                                organizationItemRow(item)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(detailBackground)
        .navigationTitle(detail.title)
        .homeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }

    private var emptyDetailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .homeCardSurface(weight: .tertiary, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("暂无待处理单品")
                    .font(.headline)
                Text(detail.emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var coverageSection: some View {
        VStack(spacing: 12) {
            Picker("分类范围", selection: $showsAllCoverageRows) {
                Text("已有分类").tag(false)
                Text("全部分类").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(4)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)

            HStack(alignment: .firstTextBaseline) {
                Text(showsAllCoverageRows ? "全部分类" : "已有分类")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(visibleCoverageRows.count)/\(coverageRows.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if visibleCoverageRows.isEmpty {
                emptyDetailCard
            } else {
                ForEach(visibleCoverageRows) { row in
                    Button {
                        guard row.count > 0 else { return }
                        onSelectCategory(row.category)
                        dismiss()
                    } label: {
                        coverageRow(row)
                    }
                    .disabled(row.count == 0)
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
        }
    }

    private func organizationItemRow(_ item: WardrobeItem) -> some View {
        HStack(spacing: 12) {
            itemThumbnail(item)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.fullDisplaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.needsDetailCompletion ? "点进详情补充图片、标签、品牌或尺码" : "资料完整，可继续搭配")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var visibleCoverageRows: [ClosetCategoryCoverage] {
        if showsAllCoverageRows {
            return coverageRows
        }

        return coverageRows.filter { $0.count > 0 }
    }

    private func coverageRow(_ row: ClosetCategoryCoverage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.count == 0 ? "plus.viewfinder" : "square.grid.2x2.fill")
                .font(.headline)
                .frame(width: 36, height: 36)
                .homeCardSurface(weight: .tertiary, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(row.category)
                        .font(.subheadline.weight(.semibold))
                    if row.isCore {
                        Text("核心")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                }
                Text(row.count == 0 ? "还没有这类单品，建议添加。" : "已有 \(row.count) 件，点击查看分类。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            if row.count > 0 {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
        .opacity(row.count == 0 ? 0.68 : 1)
    }

    private func itemThumbnail(_ item: WardrobeItem) -> some View {
        WardrobeItemImageView(item: item)
            .frame(width: 72, height: 72)
    }

    private var detailBackground: some View {
        AppAdaptiveBackground()
    }
}

private struct WardrobeTimelineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let items: [WardrobeItem]
    let onDeleted: (String) -> Void

    @State private var editingItem: WardrobeItem?
    @State private var actionMessage: String?

    private var sections: [TimelineSection] {
        Dictionary(grouping: sortedItems) { item in
            TimelinePeriod.period(for: item.createdAt)
        }
        .map { period, sectionItems in
            TimelineSection(
                period: period,
                batches: batches(from: sectionItems)
            )
        }
        .sorted { $0.period.order < $1.period.order }
    }

    private var sortedItems: [WardrobeItem] {
        items.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("入库时间线")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("按入库时间和批量导入批次回看衣橱记录，可快速修正分类、补照片或进入详情。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                timelineSummaryStrip

                if let actionMessage {
                    Label(actionMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                }

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(section.period.title)
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Text("\(section.itemCount) 件")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        LazyVStack(spacing: 12) {
                            ForEach(section.batches) { batch in
                                timelineBatchCard(batch)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(detailBackground)
        .navigationTitle("入库时间线")
        .homeInlineNavigationTitle()
        .sheet(
            isPresented: Binding(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            )
        ) {
            if let editingItem {
                EditClothingView(item: editingItem) { item in
                    actionMessage = "已更新“\(item.name)”"
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }

    private var timelineSummaryStrip: some View {
        HStack(spacing: 10) {
            summaryPill(title: "总入库", value: "\(items.count)", detail: "件")
            summaryPill(title: "今日新增", value: "\(items.filter { Calendar.current.isDateInToday($0.createdAt) }.count)", detail: "件")
            summaryPill(title: "缺少图片", value: "\(items.filter { !$0.hasPhoto }.count)", detail: "件")
        }
    }

    private func summaryPill(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func timelineBatchCard(_ batch: TimelineBatch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(batch.title)
                        .font(.subheadline.weight(.semibold))
                    Text("\(batch.items.count) 件 · \(timeTitle(batch.createdAt))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if batch.isBatch {
                    Label("批量", systemImage: "square.stack.3d.up.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                }
            }

            VStack(spacing: 8) {
                ForEach(batch.items, id: \.id) { item in
                    timelineManagementRow(item)
                }
            }
        }
        .padding(12)
        .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func timelineManagementRow(_ item: WardrobeItem) -> some View {
        VStack(spacing: 10) {
            NavigationLink {
                ClothingDetailView(item: item, onDeleted: onDeleted)
            } label: {
                HStack(spacing: 12) {
                    WardrobeItemImageView(item: item)
                        .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(item.category) · \(item.colorName) · \(item.season)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(timeTitle(item.createdAt))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary.opacity(0.88))
                    }

                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(HomePressableButtonStyle())

            HStack(spacing: 8) {
                categoryCorrectionMenu(for: item)

                Button {
                    editingItem = item
                    AppHaptics.selection()
                } label: {
                    Label(item.hasPhoto ? "编辑图片" : "补图片", systemImage: item.hasPhoto ? "photo" : "photo.badge.plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HomePressableButtonStyle())

                NavigationLink {
                    ClothingDetailView(item: item, onDeleted: onDeleted)
                } label: {
                    Label("详情", systemImage: "info.circle")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HomePressableButtonStyle())
            }
        }
        .padding(10)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func categoryCorrectionMenu(for item: WardrobeItem) -> some View {
        Menu {
            ForEach(WardrobeCategory.allCases, id: \.rawValue) { category in
                Button {
                    updateCategory(category, for: item)
                } label: {
                    Label(category.rawValue, systemImage: category.defaultSymbolName)
                }
            }
        } label: {
            Label("改分类", systemImage: "tag")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(HomePressableButtonStyle())
    }

    private func updateCategory(_ category: WardrobeCategory, for item: WardrobeItem) {
        guard item.category != category.rawValue else { return }
        item.category = category.rawValue
        item.imageSymbol = category.defaultSymbolName
        item.updatedAt = .now

        do {
            try modelContext.save()
            actionMessage = "已将“\(item.name)”改为\(category.rawValue)"
            AppHaptics.selection()
        } catch {
            actionMessage = "分类更新失败，请稍后重试。"
        }
    }

    private func batches(from items: [WardrobeItem]) -> [TimelineBatch] {
        Dictionary(grouping: items) { item in
            item.importBatchID?.uuidString ?? "single-\(item.id.uuidString)"
        }
        .map { key, batchItems in
            let sortedBatchItems = batchItems.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.createdAt > $1.createdAt
            }
            let createdAt = sortedBatchItems.first?.createdAt ?? .distantPast
            let hasBatchID = sortedBatchItems.first?.importBatchID != nil
            return TimelineBatch(
                id: key,
                createdAt: createdAt,
                isBatch: hasBatchID && sortedBatchItems.count > 1,
                items: sortedBatchItems
            )
        }
        .sorted {
            if $0.createdAt == $1.createdAt {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func timeTitle(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_Hans_CN")).month().day().hour().minute())
    }

    private var detailBackground: some View {
        AppAdaptiveBackground()
    }

    private enum TimelinePeriod: Int, CaseIterable, Identifiable {
        case today
        case yesterday
        case thisWeek
        case earlier

        var id: Int { rawValue }
        var order: Int { rawValue }

        var title: String {
            switch self {
            case .today:
                "今天"
            case .yesterday:
                "昨天"
            case .thisWeek:
                "本周"
            case .earlier:
                "更早"
            }
        }

        static func period(for date: Date, calendar: Calendar = .current) -> TimelinePeriod {
            if calendar.isDateInToday(date) {
                return .today
            }

            if calendar.isDateInYesterday(date) {
                return .yesterday
            }

            if calendar.isDate(date, equalTo: .now, toGranularity: .weekOfYear),
               calendar.isDate(date, equalTo: .now, toGranularity: .yearForWeekOfYear) {
                return .thisWeek
            }

            return .earlier
        }
    }

    private struct TimelineBatch: Identifiable {
        let id: String
        let createdAt: Date
        let isBatch: Bool
        let items: [WardrobeItem]

        var title: String {
            isBatch ? "本次导入 \(items.count) 件" : "单件入库"
        }
    }

    private struct TimelineSection: Identifiable {
        var id: Int { period.id }
        let period: TimelinePeriod
        let batches: [TimelineBatch]

        var itemCount: Int {
            batches.reduce(0) { $0 + $1.items.count }
        }
    }
}

#Preview("Closet View") {
    ClosetView()
        .modelContainer(WardrobePreviewContainer.shared)
}
