import SwiftData
import SwiftUI

struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @State private var viewMode: PlannerDisplayMode = .week
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var searchText = ""
    @State private var selectedFocusFilter: PlannerFocusFilter = .all
    @State private var selectedSortMode: PlannerSortMode = .dateAscending
    @State private var activePlanDraft: PlanCreationDraft?
    @State private var showsCreateOOTD = false
    @State private var showsAddClothing = false
    @State private var feedback: ActionFeedbackState?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    plannerReminderStatusSection
                    quickTemplateSection
                    currentFilterSection
                    planToolsSection
                    plansListSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .background(background)
            .navigationTitle("计划")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ShareLink(
                        item: plansExportText,
                        subject: Text("穿搭计划清单"),
                        message: Text("来自\(AppReleaseInfo.appName)的本地计划清单。")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(plans.isEmpty)
                    .accessibilityLabel("导出穿搭计划")

                    Button {
                        startCreatePlanFlow()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(HomeIconButtonStyle())
                    .accessibilityLabel("新建计划")
                }
            }
            .sheet(item: $activePlanDraft) { draft in
                NavigationStack {
                    CreatePlanView(draft: draft) { plan, notificationResult in
                        feedback = .planSaved(plan, notificationResult: notificationResult)
                    }
                }
            }
            .sheet(isPresented: $showsCreateOOTD) {
                NavigationStack {
                    CreateOOTDView { outfit in
                        feedback = ActionFeedbackState(
                            title: outfit.isToday ? "已保存并设为今日搭配" : "已保存为 OOTD",
                            message: "“\(outfit.title)”已保存，现在可以继续创建计划。"
                        )
                    }
                }
            }
            .sheet(isPresented: $showsAddClothing) {
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
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("安排未来几天")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("把已保存的 OOTD 绑定到某一天，再按需要设置一次本地提醒。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        summaryChip(title: "已存 OOTD", value: "\(outfits.count)")
                        summaryChip(title: "计划总数", value: "\(plans.count)")
                        summaryChip(title: "同日多排", value: "\(conflictingPlansCount)")
                    }

            Button {
                startCreatePlanFlow()
            } label: {
                Label("新建计划", systemImage: "calendar.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.2))
        }
    }

    private var plannerReminderStatusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "提醒与冲突", subtitle: plannerReminderSummary.statusTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                plannerMetricCard(title: "已开提醒", value: "\(plannerReminderSummary.enabledReminderCount)", systemImage: "bell.badge")
                plannerMetricCard(title: "失效提醒", value: "\(plannerReminderSummary.invalidReminderCount)", systemImage: "bell.slash")
                plannerMetricCard(title: "同日多排", value: "\(plannerReminderSummary.conflictingPlanCount)", systemImage: "exclamationmark.triangle")
                plannerMetricCard(title: "未绑定", value: "\(plannerReminderSummary.unlinkedPlanCount)", systemImage: "link.badge.minus")
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: plannerReminderSummary.invalidReminderCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(plannerReminderSummary.invalidReminderCount > 0 ? .orange : .green)
                    .frame(width: 34, height: 34)
                    .homeCardSurface(weight: .tertiary, cornerRadius: 17)

                VStack(alignment: .leading, spacing: 5) {
                    Text(plannerReminderSummary.statusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(plannerReminderSummary.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }
            .padding(16)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)

            if plannerReminderSummary.invalidReminderCount > 0 {
                Button {
                    Task { await clearInvalidReminders() }
                } label: {
                    Label("清理失效提醒", systemImage: "bell.slash")
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
    private var quickTemplateSection: some View {
        if outfits.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "快速排期", subtitle: defaultTemplateOutfitTitle)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PlannerQuickTemplate.allCases) { template in
                            Button {
                                activePlanDraft = template.draft(selectedOutfitID: defaultTemplateOutfitID)
                                AppHaptics.selection()
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: template.symbolName)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary.opacity(0.86))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(template.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 142, alignment: .leading)
                                .padding(14)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var currentFilterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("视图模式", selection: $viewMode) {
                ForEach(PlannerDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewMode == .day {
                DatePicker("查看日期", selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
    }

    @ViewBuilder
    private var planToolsSection: some View {
        if !plans.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "计划工具", subtitle: "\(visiblePlans.count) / \(scopedPlans.count) 条")

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("搜索标题、场景或搭配", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空计划搜索")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PlannerFocusFilter.allCases, id: \.self) { filter in
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

                if conflictingPlansCount > 0 {
                    Button {
                        selectedFocusFilter = .conflicting
                        AppHaptics.selection()
                    } label: {
                        Label("\(conflictingPlansCount) 条计划存在同日多排", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                }

                HStack(spacing: 10) {
                    Picker("排序", selection: $selectedSortMode) {
                        ForEach(PlannerSortMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ShareLink(
                        item: plansExportText,
                        subject: Text("穿搭计划清单"),
                        message: Text("来自\(AppReleaseInfo.appName)的本地计划清单。")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 42, height: 42)
                    }
                    .disabled(plans.isEmpty)
                    .accessibilityLabel("导出穿搭计划")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
            }
        }
    }

    private var plansListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: viewMode == .week ? "最近计划" : "当天计划",
                subtitle: planListSubtitle
            )

            if visiblePlans.isEmpty {
                WardrobeEmptyStateView(
                    title: emptyPlansTitle,
                    message: emptyPlansMessage,
                    systemImage: emptyPlansSystemImage,
                    actionTitle: emptyPlansActionTitle,
                    actionSystemImage: emptyPlansActionSymbol
                ) {
                        if hasActivePlanFilters {
                            clearPlanFilters()
                        } else if outfits.isEmpty {
                            startCreatePlanFlow()
                        } else {
                            startCreatePlanFlow()
                        }
                }
            } else {
                ForEach(visiblePlans, id: \.id) { plan in
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        plannerPlanRow(plan: plan)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
        }
    }

    private var visiblePlans: [OutfitPlan] {
        sortedPlans(
            scopedPlans.filter { plan in
                matchesFocusFilter(plan) && matchesSearch(plan)
            }
        )
    }

    private var scopedPlans: [OutfitPlan] {
        switch viewMode {
        case .week:
            let start = Calendar.current.startOfDay(for: .now)
            let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
            return plans.filter { $0.date >= start && $0.date < end }
        case .day:
            return plans.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
        }
    }

    private var planListSubtitle: String {
        let scopeText = viewMode == .week ? "未来 7 天" : selectedDay.formatted(.dateTime.month().day().weekday(.abbreviated))
        guard !plans.isEmpty else { return scopeText }
        if visiblePlans.count == scopedPlans.count {
            return scopeText
        }
        return "\(scopeText) · \(visiblePlans.count)/\(scopedPlans.count)"
    }

    private var emptyPlansTitle: String {
        if hasActivePlanFilters {
            return "没有匹配的计划"
        }
        return viewMode == .week ? "最近没有计划" : "当天没有计划"
    }

    private var emptyPlansMessage: String {
        if hasActivePlanFilters {
            return "没有匹配当前搜索或筛选条件的穿搭计划。"
        }
        return viewMode == .week ? "未来几天还没有穿搭计划。" : "这一天还没有安排穿搭。"
    }

    private var emptyPlansActionTitle: String {
        if hasActivePlanFilters {
            return "清空筛选"
        }
        return outfits.isEmpty ? "先建 OOTD" : "新建计划"
    }

    private var emptyPlansActionSymbol: String {
        if hasActivePlanFilters {
            return "line.3.horizontal.decrease.circle"
        }
        return outfits.isEmpty ? "wand.and.stars" : "calendar.badge.plus"
    }

    private var emptyPlansSystemImage: String {
        if hasActivePlanFilters {
            return "line.3.horizontal.decrease.circle"
        }
        return outfits.isEmpty ? "wand.and.stars" : "calendar"
    }

    private var hasActivePlanFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedFocusFilter != .all
    }

    private var plansExportText: String {
        WardrobeExporter.plansReport(from: plans)
    }

    private var plannerReminderSummary: PlannerReminderSummary {
        PlannerReminderSummary.make(plans: plans)
    }

    private var coreFlowReadiness: WardrobeCoreFlowReadiness {
        WardrobeCoreFlowReadiness.make(items: items, outfits: outfits)
    }

    private var defaultTemplateOutfitID: PersistentIdentifier? {
        if let todayOutfit = outfits.first(where: \.isToday) {
            return todayOutfit.persistentModelID
        }
        return outfits.first?.persistentModelID
    }

    private var defaultTemplateOutfitTitle: String {
        if let todayOutfit = outfits.first(where: \.isToday) {
            return "默认带入今日 OOTD · \(todayOutfit.title)"
        }
        if let firstOutfit = outfits.first {
            return "默认带入最近 OOTD · \(firstOutfit.title)"
        }
        return "先保存 OOTD"
    }

    private var background: some View {
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

    private func summaryChip(title: String, value: String) -> some View {
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

    private func plannerMetricCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.headline.monospacedDigit().weight(.semibold))
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func plannerPlanRow(plan: OutfitPlan) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(plan.date, format: .dateTime.day())
                    .font(.title2.weight(.bold))
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline)
                Text(plan.linkedOutfit?.title ?? plan.outfitSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if plan.reminderEnabled, let reminderDate = plan.reminderDate {
                    Text("提醒 · \(reminderDate.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if sameDayPlanCount(for: plan) > 1 {
                    Text("同日还有 \(sameDayPlanCount(for: plan) - 1) 条计划")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary.opacity(0.86))
                }
            }

            Spacer()

            Image(systemName: plan.reminderEnabled ? "bell.badge.fill" : "calendar")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func clearPlanFilters() {
        searchText = ""
        selectedFocusFilter = .all
        AppHaptics.selection()
    }

    private func startCreatePlanFlow() {
        guard coreFlowReadiness.canCreatePlan else {
            if coreFlowReadiness.canCreateOOTD {
                feedback = ActionFeedbackState(
                    title: coreFlowReadiness.planBlockedTitle,
                    message: coreFlowReadiness.planBlockedMessage,
                    systemImage: "wand.and.stars",
                    actionTitle: "新建 OOTD",
                    onAction: {
                        showsCreateOOTD = true
                    }
                )
            } else {
                feedback = ActionFeedbackState(
                    title: coreFlowReadiness.planBlockedTitle,
                    message: coreFlowReadiness.planBlockedMessage,
                    systemImage: "tshirt.fill",
                    actionTitle: "添加衣物",
                    onAction: {
                        showsAddClothing = true
                    }
                )
            }
            return
        }

        activePlanDraft = .blank(selectedOutfitID: defaultTemplateOutfitID)
    }

    @MainActor
    private func clearInvalidReminders() async {
        let invalidPlans = plans.filter { plan in
            guard plan.reminderEnabled else { return false }
            guard let reminderDate = plan.reminderDate else { return true }
            return reminderDate <= .now
        }

        guard !invalidPlans.isEmpty else { return }

        for plan in invalidPlans {
            plan.reminderEnabled = false
            plan.reminderDate = nil
            plan.updatedAt = .now
            await PlannerNotificationManager.removeNotification(for: plan)
        }

        do {
            try modelContext.save()
            AppHaptics.success()
            feedback = ActionFeedbackState(
                title: "已清理失效提醒",
                message: "已关闭 \(invalidPlans.count) 条过期或无效的本地提醒。",
                systemImage: "bell.slash"
            )
        } catch {
            feedback = ActionFeedbackState(
                title: "清理失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func matchesFocusFilter(_ plan: OutfitPlan) -> Bool {
        switch selectedFocusFilter {
        case .all:
            true
        case .withReminder:
            plan.reminderEnabled
        case .withoutReminder:
            !plan.reminderEnabled
            case .unlinked:
                plan.linkedOutfit == nil
            case .conflicting:
                sameDayPlanCount(for: plan) > 1
            }
        }

    private func matchesSearch(_ plan: OutfitPlan) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let searchableText = [
            plan.title,
            plan.occasion,
            plan.notes,
            plan.outfitSummary,
            plan.linkedOutfit?.title ?? "",
            plan.linkedOutfit?.summaryText ?? ""
        ].joined(separator: " ")
        return searchableText.localizedCaseInsensitiveContains(query)
    }

    private func sortedPlans(_ plans: [OutfitPlan]) -> [OutfitPlan] {
        plans.sorted { lhs, rhs in
            switch selectedSortMode {
            case .dateAscending:
                if lhs.date == rhs.date {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.date < rhs.date
            case .dateDescending:
                if lhs.date == rhs.date {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.date > rhs.date
            case .recentlyUpdated:
                if lhs.lastModifiedAt == rhs.lastModifiedAt {
                    return lhs.date < rhs.date
                }
                return lhs.lastModifiedAt > rhs.lastModifiedAt
            case .title:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private var conflictingPlansCount: Int {
        plans.filter { sameDayPlanCount(for: $0) > 1 }.count
    }

    private func sameDayPlanCount(for plan: OutfitPlan) -> Int {
        plans.filter { Calendar.current.isDate($0.date, inSameDayAs: plan.date) }.count
    }
}

private extension PlannerView {
    enum PlannerDisplayMode: CaseIterable {
        case week
        case day

        var title: String {
            switch self {
            case .week:
                "周计划"
            case .day:
                "日计划"
            }
        }
    }

    enum PlannerFocusFilter: CaseIterable {
        case all
        case withReminder
        case withoutReminder
        case unlinked
        case conflicting

        var title: String {
            switch self {
            case .all:
                "全部"
            case .withReminder:
                "有提醒"
            case .withoutReminder:
                "无提醒"
            case .unlinked:
                "未绑定"
            case .conflicting:
                "同日多排"
            }
        }

        var systemImage: String {
            switch self {
            case .all:
                "calendar"
            case .withReminder:
                "bell.badge"
            case .withoutReminder:
                "bell.slash"
            case .unlinked:
                "link.badge.minus"
            case .conflicting:
                "exclamationmark.triangle"
            }
        }
    }

    enum PlannerSortMode: CaseIterable {
        case dateAscending
        case dateDescending
        case recentlyUpdated
        case title

        var title: String {
            switch self {
            case .dateAscending:
                "日期从近到远"
            case .dateDescending:
                "日期从远到近"
            case .recentlyUpdated:
                "最近更新"
            case .title:
                "标题"
            }
        }
    }
}

#Preview("Planner") {
    PlannerView()
        .modelContainer(WardrobePreviewContainer.shared)
}
