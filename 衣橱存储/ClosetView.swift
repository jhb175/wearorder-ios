import SwiftUI
import SwiftData

struct ClosetView: View {
    @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var items: [WardrobeItem]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var selectedSeason = "全部季节"
    @State private var selectedFocusFilter: ClosetFocusFilter = .all
    @State private var selectedSortMode: ClosetSortMode = .recent
    @State private var showsAddSheet = false
    @State private var feedback: ActionFeedbackState?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: HomeMetrics.sectionSpacing) {
                    closetHeroSection
                    recentItemsSection
                    categorySection
                    clothingGridSection
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
                        showsAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(HomeIconButtonStyle())
                    .accessibilityLabel("添加衣物")
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
    private var recentItemsSection: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                closetSectionHeader(title: "最近单品", subtitle: "\(recentItems.count) 件")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(recentItems, id: \.id) { item in
                            NavigationLink {
                                ClothingDetailView(item: item) { deletedName in
                                    feedback = ActionFeedbackState(
                                        title: "已删除衣物",
                                        message: "“\(deletedName)”已从衣橱移除，相关搭配会安全保留缺失状态。",
                                        systemImage: "trash"
                                    )
                                }
                            } label: {
                                WardrobeItemCard(item: item, emphasis: .carousel)
                                    .frame(width: 184)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
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
                        applyFocusFilter(.unused)
                    }

                    closetInsightCard(
                        title: "缺少图片",
                        value: "\(organizationSnapshot.missingImageCount)",
                        detail: organizationSnapshot.missingImageCount == 0 ? "图片记录完整" : "可优先补拍照片",
                        systemImage: "photo.badge.exclamationmark"
                    ) {
                        applyFocusFilter(.missingImage)
                    }

                    closetInsightCard(
                        title: "待补资料",
                        value: "\(organizationSnapshot.detailGapCount)",
                        detail: organizationSnapshot.detailGapCount == 0 ? "基础资料完整" : "缺少图片、标签、品牌或尺码",
                        systemImage: "checklist"
                    ) {
                        applyFocusFilter(.needsDetails)
                    }

                    closetInsightCard(
                        title: "分类覆盖",
                        value: organizationSnapshot.coverageText,
                        detail: missingCategorySummary,
                        systemImage: "square.grid.2x2"
                    )

                    closetInsightCard(
                        title: "收藏单品",
                        value: "\(organizationSnapshot.favoriteCount)",
                        detail: "常穿单品可快速筛出",
                        systemImage: "heart"
                    ) {
                        selectedCategory = "收藏"
                        selectedSeason = Self.allSeasonTitle
                        selectedFocusFilter = .all
                        searchText = ""
                        AppHaptics.selection()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var closetCoverageSection: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                closetSectionHeader(title: "分类覆盖", subtitle: organizationSnapshot.coverageText)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(organizationSnapshot.categoryRows) { row in
                        closetCoverageRow(row)
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
        VStack(alignment: .leading, spacing: 14) {
            closetSectionHeader(title: "筛选与排序", subtitle: "快速整理")

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
        VStack(alignment: .leading, spacing: 14) {
            closetSectionHeader(title: "衣物库", subtitle: "\(filteredItems.count) 件")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                if filteredItems.isEmpty {
                    emptyClosetCard
                        .gridCellColumns(2)
                } else {
                    ForEach(filteredItems, id: \.id) { item in
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
                    }
                }
            }
        }
    }

    private var filteredItems: [WardrobeItem] {
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
                matchesFocus = outfitUsageCount(for: item) == 0
            case .missingImage:
                matchesFocus = item.imageData == nil
            case .needsDetails:
                matchesFocus = itemNeedsDetails(item)
            }
            let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = keyword.isEmpty
            || item.searchableFields.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesSeason && matchesFocus && matchesSearch
        }

        return sortedItems(filtered)
    }

    private var categories: [String] {
        ["全部", "收藏"] + baseCategories
    }

    private var seasonFilters: [String] {
        [Self.allSeasonTitle] + Array(Set(items.map(\.season))).sorted()
    }

    private var baseCategories: [String] {
        Array(Set(items.map(\.category))).sorted()
    }

    private var organizationSnapshot: ClosetOrganizationSnapshot {
        ClosetOrganizationSnapshot.make(items: items, outfits: outfits)
    }

    private var recentItems: [WardrobeItem] {
        items
            .sorted { lhs, rhs in
                if lhs.lastModifiedAt == rhs.lastModifiedAt {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhs.lastModifiedAt > rhs.lastModifiedAt
            }
            .prefix(6)
            .map { $0 }
    }

    private var insightsSnapshot: WardrobeInsightsSnapshot {
        WardrobeInsightsSnapshot.make(items: items)
    }

    private var unusedItemsCount: Int {
        organizationSnapshot.unusedItemCount
    }

    private var missingImageItemsCount: Int {
        organizationSnapshot.missingImageCount
    }

    private var missingCategorySummary: String {
        let missing = organizationSnapshot.missingCoreCategories
        if missing.isEmpty {
            return "核心分类已经覆盖"
        }
        return "缺少 \(missing.prefix(3).joined(separator: "、"))"
    }

    private var closetExportText: String {
        WardrobeExporter.plainText(from: items)
    }

    private var closetBackground: some View {
        ZStack {
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

            Circle()
                .fill(Color.white.opacity(0.82))
                .frame(width: 340, height: 340)
                .blur(radius: 42)
                .offset(x: -110, y: -250)
        }
    }

    private func closetSectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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

    private func applyFocusFilter(_ filter: ClosetFocusFilter) {
        selectedCategory = "全部"
        selectedSeason = Self.allSeasonTitle
        selectedFocusFilter = filter
        searchText = ""
        AppHaptics.selection()
    }

    private func handleOrganizationTask(_ task: ClosetOrganizationTask) {
        switch task.kind {
        case .addClothing:
            showsAddSheet = true
        case .showNeedsDetails:
            applyFocusFilter(.needsDetails)
        case .showUnused:
            applyFocusFilter(.unused)
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

    private func sortedItems(_ items: [WardrobeItem]) -> [WardrobeItem] {
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
                return isOrdered(lhs.category, before: rhs.category)
            case .season:
                if lhs.season == rhs.season {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return isOrdered(lhs.season, before: rhs.season)
            case .usage:
                let lhsUsage = outfitUsageCount(for: lhs)
                let rhsUsage = outfitUsageCount(for: rhs)
                if lhsUsage == rhsUsage {
                    return isOrdered(lhs.name, before: rhs.name)
                }
                return lhsUsage < rhsUsage
            }
        }
    }

    private func outfitUsageCount(for item: WardrobeItem) -> Int {
        outfits.filter { outfitUsesItem($0, item: item) }.count
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
}

private extension ClosetView {
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

#Preview("Closet View") {
    ClosetView()
        .modelContainer(WardrobePreviewContainer.shared)
}
