import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @State private var viewModel = HomeDashboardViewModel()
    @State private var weatherForecastService = WeatherForecastService()
    @AppStorage(WardrobeOnboardingState.storageKey) private var hasSeenOnboarding = false
    @State private var selectedTab: HomeTab = .home
    @State private var selectedOOTDSection: OOTDWorkspaceSection = .today
    @State private var ootdSearchText = ""
    @State private var selectedOOTDListFilter: OOTDListFilter = .all
    @State private var selectedOOTDTagFilter: String?
    @State private var selectedOOTDSortMode: OOTDPresetSortMode = .recent
    @State private var visibleOOTDPresetLimit = 8
    @State private var showsAddClothing = false
    @State private var showsRecommendationInput = false
    @State private var showsCreateOOTD = false
    @State private var activePlanDraft: PlanCreationDraft?
    @State private var activeOOTDTemplate: OOTDStarterTemplate?
    @State private var showsFirstRunOnboarding = false
    @State private var globalFeedback: ActionFeedbackState?
    @State private var hasStartedLaunchWork = false
    @AppStorage("wardrobeWeatherFallbackCity") private var fallbackWeatherCity = ""
    @AppStorage("wardrobeWeatherSourceMode") private var weatherSourceModeRawValue = WeatherSourceMode.currentLocation.rawValue
    @State private var showsWeatherCityPicker = false
    private let usesPreviewWeather: Bool
    private let ootdPresetPageSize = 8

    enum HomeTab: Hashable {
        case home
        case wardrobe
        case ootd
        case settings
    }

    private enum WeatherSourceMode: String {
        case currentLocation
        case city
    }

    enum OOTDWorkspaceSection: String, CaseIterable, Hashable {
        case today
        case plans
        case library

        var title: String {
            switch self {
            case .today:
                "今日"
            case .plans:
                "计划"
            case .library:
                "预设库"
            }
        }
    }

    init(
        previewWeather: HomeDashboardViewModel.WeatherKind? = nil,
        previewTab: HomeTab = .home,
        previewOOTDSection: OOTDWorkspaceSection = .today
    ) {
        _viewModel = State(initialValue: HomeDashboardViewModel(previewWeather: previewWeather))
        _selectedTab = State(initialValue: previewTab)
        _selectedOOTDSection = State(initialValue: previewOOTDSection)
        usesPreviewWeather = previewWeather != nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            deferredTab(.home) {
                homeTab
            }
                .tag(HomeTab.home)
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            deferredTab(.wardrobe) {
                wardrobeTab
            }
                .tag(HomeTab.wardrobe)
                .tabItem {
                    Label("衣橱", systemImage: "square.grid.2x2")
                }

            deferredTab(.ootd) {
                ootdTab
            }
                .tag(HomeTab.ootd)
                .tabItem {
                    Label("OOTD", systemImage: "wand.and.stars")
                }

            deferredTab(.settings) {
                settingsTab
            }
                .tag(HomeTab.settings)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .homeTabBarGlass()
        .sheet(isPresented: $showsAddClothing) {
            AddClothingView { item in
                globalFeedback = ActionFeedbackState(
                    title: "已保存衣物",
                    message: "“\(item.name)”已经加入数字衣橱。"
                )
            }
        }
        .sheet(isPresented: $showsRecommendationInput) {
            NavigationStack {
                RecommendationInputView(
                    defaultWeather: currentRecommendationWeather,
                    defaultTemperature: currentRecommendationTemperature,
                    weatherSource: .homeWeatherCard
                )
            }
        }
        .sheet(isPresented: $showsCreateOOTD, onDismiss: {
            activeOOTDTemplate = nil
        }) {
            NavigationStack {
                CreateOOTDView(draft: activeOOTDTemplate?.draft) { outfit in
                    selectedTab = .ootd
                    globalFeedback = ActionFeedbackState(
                        title: outfit.isToday ? "已保存并设为今日搭配" : "已保存为 OOTD",
                        message: outfit.isToday ? "首页“今日 OOTD”会立即读取“\(outfit.title)”。" : "“\(outfit.title)”已经加入你的搭配列表。"
                    )
                }
            }
        }
        .sheet(item: $activePlanDraft) { draft in
            NavigationStack {
                CreatePlanView(draft: draft) { plan, notificationResult in
                    openOOTDWorkspace(.plans)
                    globalFeedback = .planSaved(plan, notificationResult: notificationResult)
                }
            }
        }
        .sheet(isPresented: $showsFirstRunOnboarding, onDismiss: markFirstRunOnboardingDismissed) {
            WardrobeOnboardingView(
                canLoadSampleData: canLoadSampleData,
                onAction: handleOnboardingAction
            )
        }
        .sheet(isPresented: $showsWeatherCityPicker) {
            WeatherCityPickerView(
                savedCity: fallbackWeatherCity,
                onSave: { cityName in
                    fallbackWeatherCity = cityName
                    weatherSourceModeRawValue = WeatherSourceMode.city.rawValue
                    Task {
                        await loadWeatherForecast(forCity: cityName)
                    }
                },
                onUseCurrentLocation: {
                    weatherSourceModeRawValue = WeatherSourceMode.currentLocation.rawValue
                    Task {
                        await loadWeatherForecast(requestPermissionIfNeeded: true)
                    }
                }
            )
        }
        .safeAreaInset(edge: .top) {
            if let globalFeedback {
                ActionFeedbackBanner(
                    title: globalFeedback.title,
                    message: globalFeedback.message,
                    systemImage: globalFeedback.systemImage,
                    actionTitle: globalFeedback.actionTitle,
                    onAction: globalFeedback.onAction,
                    onDismiss: { self.globalFeedback = nil }
                )
                .padding(.horizontal, HomeMetrics.pagePadding)
                .padding(.top, 8)
            }
        }
        .task {
            await runLaunchWorkIfNeeded()
        }
        .onChange(of: items) { _, newValue in
            syncViewModel(items: newValue, plans: plans, outfits: outfits)
        }
        .onChange(of: plans) { _, newValue in
            syncViewModel(items: items, plans: newValue, outfits: outfits)
        }
        .onChange(of: outfits) { _, newValue in
            syncViewModel(items: items, plans: plans, outfits: newValue)
            clampVisibleOOTDPresetLimit()
        }
        .onChange(of: ootdSearchText) { _, _ in
            resetVisibleOOTDPresetLimit()
        }
        .onChange(of: selectedOOTDListFilter) { _, _ in
            resetVisibleOOTDPresetLimit()
        }
        .onChange(of: selectedOOTDTagFilter) { _, _ in
            resetVisibleOOTDPresetLimit()
        }
        .onChange(of: selectedOOTDSortMode) { _, _ in
            resetVisibleOOTDPresetLimit()
        }
    }

    private var homeTab: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    homeHeader
                    weatherSection
                    welcomeSection
                    if showsOnboardingSection {
                        onboardingSection
                    }
                    ootdSection
                    secondaryContentStack
                }
                .padding(.horizontal, HomeMetrics.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 148)
            }
            .background(atmosphericBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 56, height: 50)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            Text(AppReleaseInfo.appName)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                openUpcomingPlansFromHome()
            } label: {
                Image(systemName: "bell.badge")
            }
            .buttonStyle(HomeIconButtonStyle())
            .accessibilityLabel("查看近期计划")
        }
        .padding(.top, 2)
    }

    private func openUpcomingPlansFromHome() {
        openOOTDWorkspace(.plans)
        globalFeedback = ActionFeedbackState(
            title: viewModel.upcomingPlanSummaries.isEmpty ? "暂无近期提醒" : "查看近期计划",
            message: viewModel.upcomingPlanSummaries.isEmpty ? "创建计划并开启提醒后，这里会带你回到 OOTD 的计划页查看。" : "已切换到 OOTD 计划页，你可以查看或调整提醒。",
            systemImage: viewModel.upcomingPlanSummaries.isEmpty ? "bell.slash" : "bell.badge.fill"
        )
    }

    @ViewBuilder
    private func deferredTab<Content: View>(
        _ tab: HomeTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if selectedTab == tab {
            content()
        } else {
            Color.clear
                .background(atmosphericBackground)
                .accessibilityHidden(true)
        }
    }

    private var secondaryContentStack: some View {
        VStack(alignment: .leading, spacing: 22) {
            homePlanCalendarSection
        }
    }

    private var wardrobeTab: some View {
        ClosetView()
    }

    private var ootdTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ootdWorkspacePicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                ootdWorkspaceContent
            }
            .background(atmosphericBackground)
            .navigationTitle("OOTD")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        handleOOTDPrimaryAction()
                    } label: {
                        Image(systemName: selectedOOTDSection == .plans ? "calendar.badge.plus" : "plus")
                    }
                    .buttonStyle(HomeIconButtonStyle())
                    .accessibilityLabel(selectedOOTDSection == .plans ? "新建计划" : "新建 OOTD")
                }
            }
        }
    }

    private var ootdWorkspacePicker: some View {
        Picker("OOTD 页面", selection: $selectedOOTDSection) {
            ForEach(OOTDWorkspaceSection.allCases, id: \.self) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var ootdWorkspaceContent: some View {
        switch selectedOOTDSection {
        case .today:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ootdBuilderHeroSection
                    todayOOTDSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
        case .plans:
            PlannerView(presentationStyle: .embedded)
        case .library:
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    OOTDLibraryHealthSection(snapshot: ootdLibrarySnapshot) { task in
                        handleOOTDLibraryTask(task)
                    }
                    savedOOTDSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
        }
    }

    private func handleOOTDPrimaryAction() {
        switch selectedOOTDSection {
        case .plans:
            startCreatePlanFlow()
        case .today, .library:
            startCreateOOTDFlow()
        }
    }

    private var settingsTab: some View {
        WardrobeSettingsView()
    }

    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.welcomeTitle)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(Date.now, format: .dateTime.year().month(.wide).day().weekday(.wide))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 20)

                Text("今天")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
            }

            Text(viewModel.todaySummary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, -2)
    }

    private var showsOnboardingSection: Bool {
        items.isEmpty && outfits.isEmpty && plans.isEmpty
    }

    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "开始使用", subtitle: "3 步完成闭环")

            VStack(alignment: .leading, spacing: 14) {
                onboardingStep(
                    number: "1",
                    title: "先添加衣物",
                    message: "记录上装、下装、鞋履和包袋，推荐和 OOTD 都会从这里读取。"
                )
                onboardingStep(
                    number: "2",
                    title: "保存一套 OOTD",
                    message: "把常穿组合保存下来，也可以直接设为今日搭配。"
                )
                onboardingStep(
                    number: "3",
                    title: "安排穿搭计划",
                    message: "把 OOTD 绑定到日期，并按需要开启本地提醒。"
                )

                HStack(spacing: 10) {
                    Button {
                        showsAddClothing = true
                    } label: {
                        Label("添加第一件", systemImage: "plus.viewfinder")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)

                    if canLoadSampleData {
                        Button {
                            loadSampleData()
                        } label: {
                            Label("载入示例", systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                }
            }
            .padding(18)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.16))
        }
    }

    private func onboardingStep(number: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary.opacity(0.86))
                .frame(width: 26, height: 26)
                .homeCardSurface(weight: .tertiary, cornerRadius: 13)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                WeatherDetailView(
                    weather: viewModel.weather,
                    headline: viewModel.weatherHeadline,
                    reminder: viewModel.weatherReminder,
                    secondaryNote: viewModel.secondaryWeatherNote,
                    sourceLabel: weatherSourceLabel
                )
            } label: {
                WeatherCardView(
                    weather: viewModel.weather,
                    headline: viewModel.weatherHeadline,
                    reminder: viewModel.weatherReminder,
                    secondaryNote: viewModel.secondaryWeatherNote,
                    sourceLabel: weatherSourceLabel,
                    isAnimationActive: true
                )
            }
            .buttonStyle(HomePressableButtonStyle())

            if let callout = viewModel.weatherCallout {
                weatherForecastCallout(callout)
            }

            cityWeatherFallbackButton

            NavigationLink {
                RecommendationInputView(
                    defaultWeather: currentRecommendationWeather,
                    defaultTemperature: currentRecommendationTemperature,
                    weatherSource: .homeWeatherCard
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(viewModel.canUseForecastForRecommendation ? "按今日预报去搭配" : "获取天气后去搭配")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.16))
            .disabled(!viewModel.canUseForecastForRecommendation)
            .opacity(viewModel.canUseForecastForRecommendation ? 1 : 0.58)
        }
    }

    private func weatherForecastCallout(_ callout: HomeDashboardViewModel.WeatherCallout) -> some View {
        Button {
            handleWeatherForecastAction()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: callout.symbolName)
                    .font(.headline)
                    .frame(width: 34, height: 34)
                    .homeCardSurface(weight: .tertiary, cornerRadius: 17)

                VStack(alignment: .leading, spacing: 4) {
                    Text(callout.title)
                        .font(.subheadline.weight(.semibold))
                    Text(callout.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(callout.actionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .buttonStyle(HomePressableButtonStyle())
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
    }

    private var cityWeatherFallbackButton: some View {
        Button {
            presentCityWeatherPicker()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                Text(cityWeatherFallbackTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(HomePressableButtonStyle())
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var ootdSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "今日 OOTD", subtitle: viewModel.todayOOTDSnapshot == nil ? "等待设置" : "已保存")

            if let snapshot = viewModel.todayOOTDSnapshot {
                OOTDCardView(recommendation: OutfitRecommendation(outfit: snapshot.outfit)) {
                    OOTDDetailView(outfit: snapshot.outfit) {
                        markOutfitAsToday(snapshot.outfit)
                    }
                }
                .buttonStyle(HomePressableButtonStyle())
                if let relationMessage = snapshot.relationMessage {
                    Label(relationMessage, systemImage: "calendar.badge.checkmark")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有今日搭配")
                        .font(.headline)
                    Text(viewModel.todayOOTDEmptyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            selectedTab = .ootd
                        } label: {
                            Label("去 OOTD", systemImage: "wand.and.stars")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)

                        if !items.isEmpty {
                            Button {
                                startRecommendationFlow()
                            } label: {
                                Label("去推荐", systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                        }
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            }
        }
        .padding(.top, -4)
    }

    private var homePlanCalendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "未来穿搭", subtitle: homePlanCalendarSubtitle)

            VStack(alignment: .leading, spacing: 14) {
                if let summary = primaryUpcomingPlanSummary {
                    NavigationLink {
                        PlanDetailView(plan: summary.plan)
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(summary.plan.planKind.homeTitle, systemImage: summary.plan.planKind.symbolName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(summary.plan.title)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(summary.plan.date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_Hans_CN"))))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                Text(daysUntilText(for: summary.plan.date))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                            }

                            if let outfit = summary.plan.linkedOutfit, !outfit.orderedItems.isEmpty {
                                HStack(spacing: 10) {
                                    ForEach(Array(outfit.orderedItems.prefix(4)), id: \.id) { item in
                                        WardrobeItemImageView(item: item, cornerRadius: 14, symbolFont: .caption.weight(.semibold))
                                            .frame(width: 54, height: 54)
                                    }
                                    Spacer(minLength: 0)
                                }
                            } else {
                                Text(summary.plan.outfitSummary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            HStack {
                                Text("未来 7 天已安排 \(homePlannedDayCount) / 7 天")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Label("查看计划", systemImage: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(16)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                    }
                    .buttonStyle(HomePressableButtonStyle())

                    homeCalendarStrip

                    Button {
                        openOOTDWorkspace(.plans)
                    } label: {
                        Label("进入计划日历", systemImage: "calendar")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("未来 7 天还没有安排 OOTD。可以把常用预设放进日历，通勤、约会、旅行和特殊日子都能提前准备。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button {
                                openOOTDWorkspace(.plans)
                            } label: {
                                Label("去日历", systemImage: "calendar")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)

                            Button {
                                startCreatePlanFlow()
                            } label: {
                                Label("新建计划", systemImage: "calendar.badge.plus")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
                        }
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
        }
    }

    private var homeCalendarStrip: some View {
        HStack(spacing: 8) {
            ForEach(homePlanCalendarDays) { day in
                Button {
                    openOOTDWorkspace(.plans)
                } label: {
                    VStack(spacing: 7) {
                        Text(day.weekdayText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(day.isToday ? Color.accentColor : .secondary)
                            .lineLimit(1)

                        Text(day.dayText)
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(day.isToday ? Color.accentColor : .primary)

                        ZStack {
                            Capsule()
                                .fill(day.planCount > 0 ? Color.accentColor.opacity(day.isToday ? 0.22 : 0.16) : Color.secondary.opacity(0.12))
                                .frame(width: 24, height: 5)

                            if day.planCount > 1 {
                                Text("\(day.planCount)")
                                    .font(.caption2.monospacedDigit().weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                                    .offset(y: 11)
                            }
                        }
                        .frame(height: 17)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: day.planCount > 0 || day.isToday ? .secondary : .tertiary, cornerRadius: HomeMetrics.innerRadius)
                .accessibilityLabel(day.accessibilityLabel)
            }
        }
    }

    private var currentRecommendationWeather: RecommendationWeather? {
        viewModel.weather?.kind.recommendationWeather
    }

    private var homePlanCalendarSubtitle: String {
        if homePlannedDayCount == 0 {
            return "未来 7 天"
        }
        return "\(homePlannedDayCount) 天有安排"
    }

    private var primaryUpcomingPlanSummary: HomeDashboardViewModel.UpcomingPlanSummary? {
        viewModel.upcomingPlanSummaries.first
    }

    private var homePlannedDayCount: Int {
        homePlanCalendarDays.filter { $0.planCount > 0 }.count
    }

    private var homePlanCalendarDays: [HomePlanCalendarDay] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let endDate = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
        let groupedPlans = Dictionary(grouping: plans) { plan in
            calendar.startOfDay(for: plan.date)
        }

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  date < endDate
            else {
                return nil
            }

            return HomePlanCalendarDay(
                date: date,
                planCount: groupedPlans[date]?.count ?? 0,
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private var currentRecommendationTemperature: Int? {
        viewModel.weather?.temperature
    }

    private func daysUntilText(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: date)
        let dayCount = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        if dayCount <= 0 {
            return "今天"
        }
        if dayCount == 1 {
            return "明天"
        }
        return "还有 \(dayCount) 天"
    }

    private var weatherSourceLabel: String {
        viewModel.weather?.displaySourceTitle ?? viewModel.weatherSourceState.sourceLabel
    }

    private var cityWeatherFallbackTitle: String {
        let trimmedCity = fallbackWeatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCity.isEmpty ? "选择城市天气" : "城市天气：\(trimmedCity)"
    }

    private func handleWeatherForecastAction() {
        switch viewModel.weatherSourceState {
        case .permissionDenied:
            presentCityWeatherPicker()
        case .locating, .loadingForecast, .loadingCityForecast:
            break
        case .unavailable:
            let trimmedCity = fallbackWeatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedCity.isEmpty {
                presentCityWeatherPicker()
            } else {
                Task {
                    await loadWeatherForecast(forCity: trimmedCity)
                }
            }
        default:
            Task {
                await loadWeatherForecast(requestPermissionIfNeeded: true)
            }
        }
    }

    private func loadWeatherForecast(requestPermissionIfNeeded: Bool) async {
        guard !usesPreviewWeather else { return }

        viewModel.markForecastRequestStarted(requestPermissionIfNeeded: requestPermissionIfNeeded)

        do {
            let forecast = try await weatherForecastService.fetchTodayForecast(
                requestPermissionIfNeeded: requestPermissionIfNeeded
            )
            viewModel.applyForecast(forecast)
        } catch let error as WeatherForecastService.ForecastError {
            applyWeatherForecastError(error)
        } catch {
            viewModel.markForecastUnavailable("天气服务暂时不可用，请稍后重试。")
        }
    }

    private func loadWeatherForecast(forCity cityName: String) async {
        guard !usesPreviewWeather else { return }
        let trimmedCity = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else {
            viewModel.markForecastUnavailable(WeatherForecastService.ForecastError.invalidCityName.userMessage)
            return
        }

        viewModel.markCityForecastRequestStarted(cityName: trimmedCity)

        do {
            let forecast = try await weatherForecastService.fetchTodayForecast(cityName: trimmedCity)
            viewModel.applyForecast(forecast)
        } catch let error as WeatherForecastService.ForecastError {
            applyWeatherForecastError(error)
        } catch {
            viewModel.markForecastUnavailable("天气服务暂时不可用，请稍后重试。")
        }
    }

    private func applyWeatherForecastError(_ error: WeatherForecastService.ForecastError) {
        switch error {
        case .permissionNeeded:
            viewModel.requireLocationPermission()
        case .permissionDenied, .locationServicesDisabled:
            viewModel.markLocationPermissionDenied()
        case .locationUnavailable,
             .forecastUnavailable,
             .networkUnavailable,
             .invalidCityName,
             .cityNotFound,
             .cityLookupUnavailable,
             .weatherKitAccessDenied,
             .weatherKitUnavailable,
             .forecastDateUnavailable:
            viewModel.markForecastUnavailable(error.userMessage)
        }
    }

    private func presentCityWeatherPicker() {
        showsWeatherCityPicker = true
    }

    @MainActor
    private func runLaunchWorkIfNeeded() async {
        guard !hasStartedLaunchWork else { return }
        hasStartedLaunchWork = true

        syncViewModel()
        presentFirstRunOnboardingIfNeeded()

        await Task.yield()

        WardrobeInlineImageMigrator.migrate(items: items)

        do {
            try await Task.sleep(for: .milliseconds(550))
        } catch {
            return
        }

        await loadPreferredWeatherForecastOnLaunch()
    }

    private var preferredWeatherSourceMode: WeatherSourceMode {
        WeatherSourceMode(rawValue: weatherSourceModeRawValue) ?? .currentLocation
    }

    private func loadPreferredWeatherForecastOnLaunch() async {
        let trimmedCity = fallbackWeatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        if preferredWeatherSourceMode == .city, !trimmedCity.isEmpty {
            await loadWeatherForecast(forCity: trimmedCity)
        } else {
            await loadWeatherForecast(requestPermissionIfNeeded: false)
        }
    }

    private var coreFlowReadiness: WardrobeCoreFlowReadiness {
        WardrobeCoreFlowReadiness.make(items: items, outfits: outfits)
    }

    private var canLoadSampleData: Bool {
        AppReleaseInfo.allowsSampleDataEntry && showsOnboardingSection
    }

    private func startRecommendationFlow() {
        guard coreFlowReadiness.canGenerateRecommendation else {
            selectedTab = .wardrobe
            globalFeedback = ActionFeedbackState(
                title: coreFlowReadiness.recommendationBlockedTitle,
                message: coreFlowReadiness.recommendationBlockedMessage,
                systemImage: "sparkles",
                actionTitle: "添加衣物",
                onAction: {
                    showsAddClothing = true
                }
            )
            return
        }

        guard viewModel.canUseForecastForRecommendation else {
            globalFeedback = ActionFeedbackState(
                title: "需要今日天气预报",
                message: "请先授权定位或选择城市天气，再生成按天气搭配。",
                systemImage: "cloud.sun",
                actionTitle: "选择城市",
                onAction: {
                    presentCityWeatherPicker()
                }
            )
            return
        }

        showsRecommendationInput = true
    }

    private func startCreateOOTDFlow(template: OOTDStarterTemplate? = nil) {
        guard coreFlowReadiness.canCreateOOTD else {
            selectedTab = .wardrobe
            globalFeedback = ActionFeedbackState(
                title: coreFlowReadiness.ootdBlockedTitle,
                message: coreFlowReadiness.ootdBlockedMessage,
                systemImage: "tshirt.fill",
                actionTitle: "添加衣物",
                onAction: {
                    showsAddClothing = true
                }
            )
            return
        }

        activeOOTDTemplate = template
        showsCreateOOTD = true
    }

    private func startCreatePlanFlow(
        selectedOutfitID: PersistentIdentifier? = nil,
        selectedOutfit: OOTDOutfit? = nil
    ) {
        openOOTDWorkspace(.plans)

        guard coreFlowReadiness.canCreatePlan else {
            if coreFlowReadiness.canCreateOOTD {
                globalFeedback = ActionFeedbackState(
                    title: coreFlowReadiness.planBlockedTitle,
                    message: coreFlowReadiness.planBlockedMessage,
                    systemImage: "wand.and.stars",
                    actionTitle: "新建 OOTD",
                    onAction: {
                        startCreateOOTDFlow()
                    }
                )
            } else {
                selectedTab = .wardrobe
                globalFeedback = ActionFeedbackState(
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

        if let selectedOutfit {
            activePlanDraft = .arrangingPreset(selectedOutfit)
        } else {
            activePlanDraft = .blank(selectedOutfitID: selectedOutfitID ?? defaultPlanPresetID)
        }
    }

    private func openOOTDWorkspace(_ section: OOTDWorkspaceSection) {
        selectedOOTDSection = section
        selectedTab = .ootd
    }

    private var defaultPlanPresetID: PersistentIdentifier? {
        if let todayOutfit = outfits.first(where: \.isToday) {
            return todayOutfit.persistentModelID
        }
        return outfits.first?.persistentModelID
    }

    private func presentFirstRunOnboardingIfNeeded() {
        guard WardrobeOnboardingState.shouldPresent(
            hasSeenOnboarding: hasSeenOnboarding,
            isPreview: usesPreviewWeather,
            isEmptyWardrobe: showsOnboardingSection
        ) else {
            return
        }

        showsFirstRunOnboarding = true
    }

    private func handleOnboardingAction(_ action: WardrobeOnboardingAction) {
        hasSeenOnboarding = true
        showsFirstRunOnboarding = false

        switch action {
        case .addClothing:
            showsAddClothing = true
        case .loadSampleData:
            loadSampleData()
        case .openSettings:
            selectedTab = .settings
        case .dismiss:
            break
        }
    }

    private func markFirstRunOnboardingDismissed() {
        if !hasSeenOnboarding {
            hasSeenOnboarding = true
        }
    }

    private func loadSampleData() {
        guard canLoadSampleData else {
            globalFeedback = ActionFeedbackState(
                title: "已有衣橱数据",
                message: AppReleaseInfo.allowsSampleDataEntry ? "示例数据只会在完全空白的新衣橱里载入，避免混入你的真实数据。" : "正式版本不提供示例数据入口，请直接添加真实衣物。",
                systemImage: "info.circle.fill"
            )
            return
        }

        do {
            let summary = WardrobeSampleDataLoader.insertSampleData(into: modelContext)
            try modelContext.save()
            AppHaptics.success()
            globalFeedback = ActionFeedbackState(
                title: "已载入示例衣橱",
                message: "新增 \(summary.itemCount) 件衣物、\(summary.outfitCount) 套 OOTD 和 \(summary.planCount) 条计划，之后可以逐件编辑或删除。",
                systemImage: "sparkles"
            )
        } catch {
            globalFeedback = ActionFeedbackState(
                title: "示例数据载入失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private var ootdBuilderHeroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的 OOTD")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("把常用组合保存成 OOTD 预设，今天或未来某天都能直接套用。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                summaryChip(title: "已保存", value: "\(outfits.count)")
                summaryChip(title: "今日搭配", value: viewModel.todayOutfit == nil ? "未设置" : "已设置")
                summaryChip(title: "可选单品", value: "\(items.count)")
            }

            HStack(spacing: 12) {
                Button {
                    startCreateOOTDFlow()
                } label: {
                    Label("新建 OOTD", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.2))

                NavigationLink {
                    RecommendationInputView(
                        defaultWeather: currentRecommendationWeather,
                        defaultTemperature: currentRecommendationTemperature,
                        weatherSource: .ootdTab
                    )
                } label: {
                    Label("轻量推荐", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
            }

            if AppReleaseInfo.allowsAIStylistEntry {
                NavigationLink {
                    AIOutfitGenerationView(weather: viewModel.weather)
                } label: {
                    AIStylistEntryCard()
                }
                .buttonStyle(HomePressableButtonStyle())
            }

            if coreFlowReadiness.canCreateOOTD {
                OOTDTemplateStrip { template in
                    startCreateOOTDFlow(template: template)
                }
            }
        }
    }

    private var todayOOTDSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "今日搭配", subtitle: viewModel.todayOutfit == nil ? "还未设置" : "当前读取中")

            if let todayOutfit = viewModel.todayOutfit {
                OOTDCardView(recommendation: OutfitRecommendation(outfit: todayOutfit)) {
                    OOTDDetailView(outfit: todayOutfit) {
                        markOutfitAsToday(todayOutfit)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有设置今日搭配")
                        .font(.headline)
                    Text("先新建一套 OOTD，并在保存时勾选“设为今日搭配”，首页就会开始读取。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            }
        }
    }

    private var savedOOTDSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "OOTD 预设", subtitle: ootdListSubtitle)

            if outfits.isEmpty {
                Text("还没有保存的 OOTD 预设。先从衣橱里选单品，保存第一套常用组合。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            } else if visibleOOTDOutfits.isEmpty {
                OOTDFilterControls(
                    searchText: $ootdSearchText,
                    listFilter: $selectedOOTDListFilter,
                    tagFilter: $selectedOOTDTagFilter,
                    sortMode: $selectedOOTDSortMode,
                    availableTags: availableOOTDTagFilters
                )
                OOTDEmptySearchState {
                    ootdSearchText = ""
                    selectedOOTDListFilter = .all
                    selectedOOTDTagFilter = nil
                    selectedOOTDSortMode = .recent
                }
            } else {
                OOTDFilterControls(
                    searchText: $ootdSearchText,
                    listFilter: $selectedOOTDListFilter,
                    tagFilter: $selectedOOTDTagFilter,
                    sortMode: $selectedOOTDSortMode,
                    availableTags: availableOOTDTagFilters
                )

                ForEach(displayedOOTDOutfits, id: \.id) { outfit in
                    OOTDPresetCard(
                        outfit: outfit,
                        onMarkAsToday: { markOutfitAsToday(outfit) },
                        onScheduleToDate: { startCreatePlanFlow(selectedOutfit: outfit) }
                    )
                }

                if hasMoreOOTDPresets {
                    Button {
                        visibleOOTDPresetLimit += ootdPresetPageSize
                        AppHaptics.selection()
                    } label: {
                        HStack {
                            Text("继续加载预设")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(displayedOOTDOutfits.count)/\(visibleOOTDOutfits.count)")
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                }
            }
        }
    }

    private var atmosphericBackground: some View {
        AppAdaptiveBackground()
    }

    private func summaryChip(title: String, value: String, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 10 : 12)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
    }

    private func syncViewModel(
        items: [WardrobeItem]? = nil,
        plans: [OutfitPlan]? = nil,
        outfits: [OOTDOutfit]? = nil
    ) {
        let currentItems = items ?? self.items
        let currentPlans = plans ?? self.plans
        let currentOutfits = outfits ?? self.outfits
        viewModel.update(
            items: currentItems,
            plans: currentPlans,
            outfits: currentOutfits
        )
    }

    private func markOutfitAsToday(_ outfit: OOTDOutfit) {
        for existing in outfits where existing.isToday {
            existing.isToday = false
            existing.updatedAt = .now
        }

        outfit.isToday = true
        outfit.updatedAt = .now
        do {
            try modelContext.save()
            AppHaptics.success()
        } catch {
            globalFeedback = ActionFeedbackState(
                title: "今日搭配保存失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func upcomingPlanSummaryRow(summary: HomeDashboardViewModel.UpcomingPlanSummary) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.plan.date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(summary.plan.date, format: .dateTime.day())
                    .font(.title2.weight(.bold))
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.plan.title)
                    .font(.headline)
                Text(summary.outfitTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let relationMessage = summary.relationMessage {
                    Text(relationMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary.opacity(0.84))
                }
                if let reminderText = summary.reminderText {
                    Text("提醒 · \(reminderText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: summary.plan.reminderEnabled ? "bell.badge.fill" : "calendar")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

}

private extension ContentView {
    var ootdListSubtitle: String {
        guard !outfits.isEmpty else { return "0 套" }
        if visibleOOTDOutfits.count == outfits.count {
            return "\(outfits.count) 套"
        }
        return "\(visibleOOTDOutfits.count) / \(outfits.count) 套"
    }

    var ootdLibrarySnapshot: OOTDLibrarySnapshot {
        OOTDLibrarySnapshot.make(outfits: outfits, plans: plans)
    }

    var availableOOTDTagFilters: [String] {
        let tags = outfits.flatMap(\.presetTags)
        return Array(Set(tags)).sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    var visibleOOTDOutfits: [OOTDOutfit] {
        let filteredOutfits = outfits.filter { outfit in
            matchesOOTDFilter(outfit) &&
            matchesOOTDSearch(outfit) &&
            matchesOOTDTagFilter(outfit)
        }
        return sortedOOTDOutfits(filteredOutfits)
    }

    var displayedOOTDOutfits: [OOTDOutfit] {
        Array(visibleOOTDOutfits.prefix(visibleOOTDPresetLimit))
    }

    var hasMoreOOTDPresets: Bool {
        displayedOOTDOutfits.count < visibleOOTDOutfits.count
    }

    func resetVisibleOOTDPresetLimit() {
        visibleOOTDPresetLimit = ootdPresetPageSize
    }

    func clampVisibleOOTDPresetLimit() {
        if visibleOOTDPresetLimit < ootdPresetPageSize {
            visibleOOTDPresetLimit = ootdPresetPageSize
        } else if visibleOOTDOutfits.count < visibleOOTDPresetLimit {
            visibleOOTDPresetLimit = max(ootdPresetPageSize, visibleOOTDOutfits.count)
        }
    }

    func matchesOOTDFilter(_ outfit: OOTDOutfit) -> Bool {
        switch selectedOOTDListFilter {
        case .all:
            true
        case .today:
            outfit.isToday
        case .planned:
            plans.contains { $0.linkedOutfit?.id == outfit.id }
        case .unplanned:
            !plans.contains { $0.linkedOutfit?.id == outfit.id }
        case .incomplete:
            outfit.isIncomplete
        }
    }

    func matchesOOTDSearch(_ outfit: OOTDOutfit) -> Bool {
        let query = ootdSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let itemFields = outfit.orderedItems.flatMap { item in
            item.searchableFields + item.styleTags
        }
        let searchableText = ([outfit.title, outfit.notes, outfit.summaryText] + itemFields + outfit.presetTags)
            .joined(separator: " ")
        return searchableText.localizedCaseInsensitiveContains(query)
    }

    func matchesOOTDTagFilter(_ outfit: OOTDOutfit) -> Bool {
        guard let selectedOOTDTagFilter else { return true }
        return outfit.presetTags.contains { $0.localizedCaseInsensitiveCompare(selectedOOTDTagFilter) == .orderedSame }
    }

    func sortedOOTDOutfits(_ outfits: [OOTDOutfit]) -> [OOTDOutfit] {
        switch selectedOOTDSortMode {
        case .recent:
            return outfits.sorted { lhs, rhs in
                if lhs.lastModifiedAt == rhs.lastModifiedAt {
                    return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
                return lhs.lastModifiedAt > rhs.lastModifiedAt
            }
        case .title:
            return outfits.sorted { lhs, rhs in
                lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
        case .plannedCount:
            return outfits.sorted { lhs, rhs in
                let lhsCount = plannedCount(for: lhs)
                let rhsCount = plannedCount(for: rhs)
                if lhsCount == rhsCount {
                    return lhs.lastModifiedAt > rhs.lastModifiedAt
                }
                return lhsCount > rhsCount
            }
        }
    }

    func plannedCount(for outfit: OOTDOutfit) -> Int {
        plans.reduce(0) { count, plan in
            count + ((plan.linkedOutfit?.id == outfit.id) ? 1 : 0)
        }
    }

    func handleOOTDLibraryTask(_ task: OOTDLibraryTask) {
        switch task.kind {
        case .createOOTD:
            startCreateOOTDFlow()
        case .showAll:
            selectedOOTDListFilter = .all
            selectedOOTDTagFilter = nil
            ootdSearchText = ""
            AppHaptics.selection()
        case .showIncomplete:
            selectedOOTDListFilter = .incomplete
            selectedOOTDTagFilter = nil
            ootdSearchText = ""
            AppHaptics.selection()
        case .showUnplanned:
            selectedOOTDListFilter = .unplanned
            selectedOOTDTagFilter = nil
            ootdSearchText = ""
            AppHaptics.selection()
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(WardrobePreviewContainer.shared)
}

#Preview("Weather Lab") {
    ContentView(previewWeather: .sunny)
        .modelContainer(WardrobePreviewContainer.shared)
}

#Preview("Home Default") {
    ContentView(previewWeather: .partlyCloudy)
        .modelContainer(WardrobePreviewContainer.shared)
}

#Preview("Home Dark") {
    ContentView(previewWeather: .thunderstorm)
        .preferredColorScheme(.dark)
        .modelContainer(WardrobePreviewContainer.shared)
}

#Preview("Home Complete") {
    ContentView(previewWeather: .drizzle)
        .modelContainer(WardrobePreviewContainer.shared)
}

#Preview("Wardrobe Tab") {
    ContentView(previewWeather: .sunny, previewTab: .wardrobe)
        .modelContainer(WardrobePreviewContainer.shared)
}

#Preview("OOTD Tab") {
    ContentView(previewWeather: .partlyCloudy, previewTab: .ootd)
        .modelContainer(WardrobePreviewContainer.shared)
}

#Preview("Settings Tab") {
    ContentView(previewWeather: .partlyCloudy, previewTab: .settings)
        .modelContainer(WardrobePreviewContainer.shared)
}
