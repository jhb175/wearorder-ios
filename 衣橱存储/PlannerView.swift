import SwiftData
import SwiftUI

struct PlannerView: View {
    enum PresentationStyle {
        case standalone
        case embedded
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @State private var viewMode: PlannerDisplayMode = .week
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var displayedMonth = Calendar.current.startOfMonth(for: .now)
    @State private var searchText = ""
    @State private var selectedFocusFilter: PlannerFocusFilter = .all
    @State private var selectedKindFilter: OutfitPlanKind?
    @State private var selectedSortMode: PlannerSortMode = .dateAscending
    @State private var activePlanDraft: PlanCreationDraft?
    @State private var showsCreateOOTD = false
    @State private var showsAddClothing = false
    @State private var feedback: ActionFeedbackState?
    private let presentationStyle: PresentationStyle

    init(presentationStyle: PresentationStyle = .standalone) {
        self.presentationStyle = presentationStyle
    }

    var body: some View {
        Group {
            if presentationStyle == .standalone {
                NavigationStack {
                    plannerContent
                        .navigationTitle("计划")
                        .toolbar {
                            plannerToolbar
                        }
                }
            } else {
                plannerContent
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

    private var plannerContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                plannerCalendarSection
                weeklyOutfitOverviewSection
                plannerReminderStatusSection
                quickTemplateSection
                planToolsSection
                plansListSection
            }
            .padding(.horizontal, 20)
            .padding(.top, presentationStyle == .standalone ? 16 : 6)
            .padding(.bottom, 120)
        }
        .background(background)
    }

    @ToolbarContentBuilder
    private var plannerToolbar: some ToolbarContent {
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("安排未来几天")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("把已保存的 OOTD 预设安排到某一天，再按需要设置一次本地提醒。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        summaryChip(title: "OOTD 预设", value: "\(outfits.count)")
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

    private var weeklyOutfitOverviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "未来一周", subtitle: weekOverviewSubtitle)

            VStack(spacing: 10) {
                ForEach(weekOverviewDays) { day in
                    weekOverviewRow(day)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
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

    private var plannerCalendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "计划日历", subtitle: calendarSectionSubtitle)

            VStack(alignment: .leading, spacing: 16) {
                calendarMonthHeader

                Picker("计划范围", selection: $viewMode) {
                    ForEach(PlannerDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                calendarWeekdayHeader

                LazyVGrid(columns: calendarColumns, spacing: 8) {
                    ForEach(calendarDays) { day in
                        calendarDayButton(day)
                    }
                }

                selectedDayPlanPreview
            }
            .padding(14)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
        }
    }

    private var calendarMonthHeader: some View {
        HStack(spacing: 10) {
            Button {
                moveDisplayedMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: 17)
            .accessibilityLabel("上个月")

            VStack(alignment: .leading, spacing: 2) {
                Text(displayedMonth.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_Hans_CN"))))
                    .font(.headline.weight(.semibold))
                Text("点选日期查看当天 OOTD 计划")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                selectToday()
            } label: {
                Text("今天")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)

            Button {
                moveDisplayedMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: 17)
            .accessibilityLabel("下个月")
        }
    }

    private var calendarWeekdayHeader: some View {
        LazyVGrid(columns: calendarColumns, spacing: 8) {
            ForEach(calendarWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func calendarDayButton(_ day: PlannerCalendarDay) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day.date)
        let firstPlan = day.plans.first

        return Button {
            selectCalendarDay(day.date)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(day.date.formatted(.dateTime.day().locale(Locale(identifier: "zh_Hans_CN"))))
                        .font(.caption.weight(isSelected || isToday ? .bold : .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Spacer(minLength: 0)

                    if !day.plans.isEmpty {
                        Text("\(day.plans.count)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(isSelected ? .white : .accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.12))
                            )
                    }
                }

                Spacer(minLength: 0)

                if let firstPlan {
                    Text(firstPlan.linkedOutfit?.title ?? firstPlan.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Circle()
                        .fill(isToday ? Color.accentColor.opacity(0.5) : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(8)
            .background(calendarDayBackground(isSelected: isSelected, isToday: isToday))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isToday && !isSelected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .opacity(day.isInDisplayedMonth ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendarDayAccessibilityLabel(day))
    }

    private var selectedDayPlanPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedDay.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_Hans_CN"))))
                        .font(.subheadline.weight(.semibold))
                    Text(selectedDayPlans.isEmpty ? "这天还没有 OOTD 计划" : "\(selectedDayPlans.count) 条 OOTD 计划")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    startCreatePlanFlow(on: selectedDay)
                } label: {
                    Label("安排这天", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
            }

            if selectedDayPlans.isEmpty {
                Text("可以把已保存的 OOTD 预设放到这一天，后续也能接入旅行、天气和 AI 推荐。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .homeCardSurface(weight: .tertiary, cornerRadius: 16)
            } else {
                ForEach(selectedDayPlans.prefix(2), id: \.id) { plan in
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        calendarPlanPreviewRow(plan)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }

                if selectedDayPlans.count > 2 {
                    Text("还有 \(selectedDayPlans.count - 2) 条计划，可在下方列表继续查看。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func calendarPlanPreviewRow(_ plan: OutfitPlan) -> some View {
        HStack(spacing: 10) {
            Image(systemName: plan.linkedOutfit == nil ? plan.planKind.symbolName : "checkmark.seal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(plan.linkedOutfit == nil ? Color.secondary : Color.green)
                .frame(width: 30, height: 30)
                .homeCardSurface(weight: .tertiary, cornerRadius: 15)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(plan.planKind.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Text(plan.linkedOutfit?.summaryText ?? plan.outfitSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if plan.reminderEnabled, let reminderDate = plan.reminderDate {
                Text(reminderDate.formatted(.dateTime.hour().minute().locale(Locale(identifier: "zh_Hans_CN"))))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .homeCardSurface(weight: .tertiary, cornerRadius: 16)
    }

    private func weekOverviewRow(_ day: WeekOverviewDay) -> some View {
        let primaryPlan = day.plans.first

        return HStack(spacing: 12) {
            VStack(spacing: 3) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "zh_Hans_CN"))))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(day.date.formatted(.dateTime.day().locale(Locale(identifier: "zh_Hans_CN"))))
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(day.isToday ? Color.accentColor : .primary)
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 5) {
                if let primaryPlan {
                    HStack(spacing: 6) {
                        Label(primaryPlan.planKind.title, systemImage: primaryPlan.planKind.symbolName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(primaryPlan.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }

                    Text(primaryPlan.linkedOutfit?.summaryText ?? primaryPlan.outfitSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(day.isToday ? "今天还没安排 OOTD" : "未安排")
                        .font(.subheadline.weight(.semibold))
                    Text("可以从预设库快速排期")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let outfit = primaryPlan?.linkedOutfit, !outfit.orderedItems.isEmpty {
                HStack(spacing: -9) {
                    ForEach(Array(outfit.orderedItems.prefix(3)), id: \.id) { item in
                        WardrobeItemImageView(item: item, cornerRadius: 11, symbolFont: .caption2.weight(.semibold))
                            .frame(width: 38, height: 38)
                            .overlay {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                            }
                    }
                }
                .frame(width: 72, alignment: .trailing)
            } else {
                Button {
                    startCreatePlanFlow(on: day.date)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: 18)
                .accessibilityLabel("安排 \(day.date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_Hans_CN"))))")
            }
        }
        .padding(12)
        .homeCardSurface(weight: primaryPlan == nil ? .tertiary : .secondary, cornerRadius: 18)
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
                        Button {
                            selectedKindFilter = nil
                            AppHaptics.selection()
                        } label: {
                            Label("全部类型", systemImage: "square.grid.2x2")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: selectedKindFilter == nil ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )

                        ForEach(OutfitPlanKind.allCases) { kind in
                            Button {
                                selectedKindFilter = kind
                                AppHaptics.selection()
                            } label: {
                                Label(kind.title, systemImage: kind.symbolName)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(
                                weight: selectedKindFilter == kind ? .secondary : .tertiary,
                                cornerRadius: HomeMetrics.pillRadius
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

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
                matchesKindFilter(plan) && matchesFocusFilter(plan) && matchesSearch(plan)
            }
        )
    }

    private var selectedDayPlans: [OutfitPlan] {
        sortedPlans(plans.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) })
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

    private var calendarSectionSubtitle: String {
        if selectedDayPlans.isEmpty {
            return selectedDay.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_Hans_CN")))
        }
        return "\(selectedDay.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_Hans_CN")))) · \(selectedDayPlans.count) 条"
    }

    private var calendarDays: [PlannerCalendarDay] {
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: displayedMonth)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let leadingDays = calendar.mondayFirstWeekdayOffset(for: monthStart)
        let totalDayCount = ((leadingDays + dayRange.count + 6) / 7) * 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let groupedPlans = Dictionary(grouping: plans) { plan in
            calendar.startOfDay(for: plan.date)
        }

        return (0..<totalDayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let dayKey = calendar.startOfDay(for: date)
            let dayPlans = (groupedPlans[dayKey] ?? []).sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.date < rhs.date
            }

            return PlannerCalendarDay(
                date: dayKey,
                isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                plans: dayPlans
            )
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 36), spacing: 8), count: 7)
    }

    private var calendarWeekdaySymbols: [String] {
        ["一", "二", "三", "四", "五", "六", "日"]
    }

    private var weekOverviewDays: [WeekOverviewDay] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let groupedPlans = Dictionary(grouping: plans) { plan in
            calendar.startOfDay(for: plan.date)
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let dayPlans = sortedPlans(groupedPlans[date] ?? [])
            return WeekOverviewDay(
                date: date,
                plans: dayPlans,
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private var weekOverviewSubtitle: String {
        let arrangedDayCount = weekOverviewDays.filter { !$0.plans.isEmpty }.count
        return arrangedDayCount == 0 ? "7 天待安排" : "已安排 \(arrangedDayCount) / 7 天"
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
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedFocusFilter != .all || selectedKindFilter != nil
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
            return "默认套用今日预设 · \(todayOutfit.title)"
        }
        if let firstOutfit = outfits.first {
            return "默认套用最近预设 · \(firstOutfit.title)"
        }
        return "先保存 OOTD"
    }

    private var background: some View {
        AppAdaptiveBackground()
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
                HStack(spacing: 6) {
                    Label(plan.planKind.title, systemImage: plan.planKind.symbolName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(plan.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(plan.linkedOutfit?.title ?? plan.outfitSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if plan.reminderEnabled, let reminderDate = plan.reminderDate {
                    Text("提醒 · \(reminderDate.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !plan.trimmedLocationName.isEmpty || !plan.trimmedWeatherCityName.isEmpty {
                    Text(plan.contextSummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if sameDayPlanCount(for: plan) > 1 {
                    Text("同日还有 \(sameDayPlanCount(for: plan) - 1) 条计划")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary.opacity(0.86))
                }
            }

            Spacer()

            Image(systemName: plan.reminderEnabled ? "bell.badge.fill" : plan.planKind.symbolName)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    @ViewBuilder
    private func calendarDayBackground(isSelected: Bool, isToday: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.gradient)
        } else if isToday {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
        }
    }

    private func calendarDayAccessibilityLabel(_ day: PlannerCalendarDay) -> String {
        let dateText = day.date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_Hans_CN")))
        if day.plans.isEmpty {
            return "\(dateText)，没有计划"
        }
        return "\(dateText)，\(day.plans.count) 条 OOTD 计划"
    }

    private func selectCalendarDay(_ date: Date) {
        selectedDay = Calendar.current.startOfDay(for: date)
        displayedMonth = Calendar.current.startOfMonth(for: date)
        viewMode = .day
        AppHaptics.selection()
    }

    private func selectToday() {
        let today = Calendar.current.startOfDay(for: .now)
        selectedDay = today
        displayedMonth = Calendar.current.startOfMonth(for: today)
        viewMode = .day
        AppHaptics.selection()
    }

    private func moveDisplayedMonth(by value: Int) {
        displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        AppHaptics.selection()
    }

    private func clearPlanFilters() {
        searchText = ""
        selectedFocusFilter = .all
        selectedKindFilter = nil
        AppHaptics.selection()
    }

    private func startCreatePlanFlow(on date: Date? = nil) {
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

        activePlanDraft = planDraft(on: date)
    }

    private func planDraft(on date: Date?) -> PlanCreationDraft {
        guard let date else {
            return .blank(selectedOutfitID: defaultTemplateOutfitID)
        }

        let calendar = Calendar.current
        let planDate = calendar.startOfDay(for: date)
        let reminderTime = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: planDate) ?? planDate

        return PlanCreationDraft(
            selectedOutfitID: defaultTemplateOutfitID,
            planKind: .daily,
            title: "新的穿搭计划",
            occasion: "穿搭安排",
            locationName: "",
            weatherCityName: "",
            notes: "",
            date: planDate,
            reminderEnabled: reminderTime > .now,
            reminderTime: reminderTime
        )
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

    private func matchesKindFilter(_ plan: OutfitPlan) -> Bool {
        guard let selectedKindFilter else { return true }
        return plan.planKind == selectedKindFilter
    }

    private func matchesSearch(_ plan: OutfitPlan) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let searchableText = [
            plan.planKind.title,
            plan.planKind.listTitle,
            plan.title,
            plan.occasion,
            plan.locationName,
            plan.weatherCityName,
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
    struct PlannerCalendarDay: Identifiable {
        let date: Date
        let isInDisplayedMonth: Bool
        let plans: [OutfitPlan]

        var id: Date { date }
    }

    struct WeekOverviewDay: Identifiable {
        let date: Date
        let plans: [OutfitPlan]
        let isToday: Bool

        var id: Date { date }
    }

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

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }

    func mondayFirstWeekdayOffset(for date: Date) -> Int {
        let weekday = component(.weekday, from: date)
        return (weekday + 5) % 7
    }
}

#Preview("Planner") {
    PlannerView()
        .modelContainer(WardrobePreviewContainer.shared)
}
