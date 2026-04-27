import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
typealias WardrobePlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias WardrobePlatformImage = NSImage
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @State private var viewModel = HomeDashboardViewModel()
    @State private var weatherForecastService = WeatherForecastService()
    @AppStorage(WardrobeOnboardingState.storageKey) private var hasSeenOnboarding = false
    @State private var selectedTab: HomeTab = .home
    @State private var ootdSearchText = ""
    @State private var selectedOOTDListFilter: OOTDListFilter = .all
    @State private var showsAddClothing = false
    @State private var showsRecommendationInput = false
    @State private var showsCreateOOTD = false
    @State private var showsCreatePlan = false
    @State private var activeOOTDTemplate: OOTDStarterTemplate?
    @State private var showsBackupExporter = false
    @State private var showsBackupImporter = false
    @State private var showsFirstRunOnboarding = false
    @State private var backupExportDocument = WardrobeBackupFile()
    @State private var backupExportFilename = "wardrobe-backup.json"
    @State private var globalFeedback: ActionFeedbackState?
    @AppStorage("wardrobeWeatherFallbackCity") private var fallbackWeatherCity = ""
    @State private var showsWeatherCityPicker = false
    private let usesPreviewWeather: Bool

    enum HomeTab: Hashable {
        case home
        case wardrobe
        case ootd
        case plans
        case settings
    }

    init(
        previewWeather: HomeDashboardViewModel.WeatherKind? = nil,
        previewTab: HomeTab = .home
    ) {
        _viewModel = State(initialValue: HomeDashboardViewModel(previewWeather: previewWeather))
        _selectedTab = State(initialValue: previewTab)
        usesPreviewWeather = previewWeather != nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tag(HomeTab.home)
                .tabItem {
                    Label("首页", systemImage: "house")
                }

            wardrobeTab
                .tag(HomeTab.wardrobe)
                .tabItem {
                    Label("衣橱", systemImage: "square.grid.2x2")
                }

            ootdTab
                .tag(HomeTab.ootd)
                .tabItem {
                    Label("OOTD", systemImage: "wand.and.stars")
                }

            plansTab
                .tag(HomeTab.plans)
                .tabItem {
                    Label("计划", systemImage: "calendar.badge.clock")
                }

            settingsTab
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
        .sheet(isPresented: $showsCreatePlan) {
            NavigationStack {
                CreatePlanView { plan, notificationResult in
                    selectedTab = .plans
                    globalFeedback = .planSaved(plan, notificationResult: notificationResult)
                }
            }
        }
        .sheet(isPresented: $showsFirstRunOnboarding) {
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
                    Task {
                        await loadWeatherForecast(forCity: cityName)
                    }
                },
                onUseCurrentLocation: {
                    Task {
                        await loadWeatherForecast(requestPermissionIfNeeded: true)
                    }
                }
            )
        }
        .fileExporter(
            isPresented: $showsBackupExporter,
            document: backupExportDocument,
            contentType: .json,
            defaultFilename: backupExportFilename,
            onCompletion: handleBackupExportResult
        )
        .fileImporter(
            isPresented: $showsBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleBackupImportResult
        )
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
            syncViewModel()
            presentFirstRunOnboardingIfNeeded()
            await loadWeatherForecast(requestPermissionIfNeeded: false)
        }
        .onChange(of: items) { _, newValue in
            syncViewModel(items: newValue, plans: plans, outfits: outfits)
        }
        .onChange(of: plans) { _, newValue in
            syncViewModel(items: items, plans: newValue, outfits: outfits)
        }
        .onChange(of: outfits) { _, newValue in
            syncViewModel(items: items, plans: plans, outfits: newValue)
        }
    }

    private var homeTab: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(AppReleaseInfo.appName)
                        .font(.headline.weight(.semibold))
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    ShareLink(
                        item: fullDataExportText,
                        subject: Text("\(AppReleaseInfo.appName)完整报告"),
                        message: Text("包含衣橱、OOTD 和计划的本地数据报告。")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!hasExportableData)
                    .accessibilityLabel("导出完整报告")

                    Button {
                        selectedTab = .plans
                        globalFeedback = ActionFeedbackState(
                            title: viewModel.upcomingPlanSummaries.isEmpty ? "暂无近期提醒" : "查看近期计划",
                            message: viewModel.upcomingPlanSummaries.isEmpty ? "创建计划并开启提醒后，这里会带你回到计划页查看。" : "已切换到计划页，你可以查看或调整提醒。",
                            systemImage: viewModel.upcomingPlanSummaries.isEmpty ? "bell.slash" : "bell.badge.fill"
                        )
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                    .buttonStyle(HomeIconButtonStyle())
                    .accessibilityLabel("查看近期计划")
                }
            }
        }
    }

    private var secondaryContentStack: some View {
        VStack(alignment: .leading, spacing: 22) {
            quickActionsSection
            lightweightOverviewSection
            dataBackupSection
            weeklyPlansSection
        }
    }

    private var wardrobeTab: some View {
        ClosetView()
    }

    private var ootdTab: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ootdBuilderHeroSection
                    todayOOTDSection
                    ootdLibraryHealthSection
                    savedOOTDSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .background(atmosphericBackground)
            .navigationTitle("OOTD")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startCreateOOTDFlow()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(HomeIconButtonStyle())
                    .accessibilityLabel("新建 OOTD")
                }
            }
        }
    }

    private var plansTab: some View {
        PlannerView()
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
            sectionHeader(title: "开始使用", subtitle: "3 步完成闭环")

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
            WeatherCardView(
                weather: viewModel.weather,
                headline: viewModel.weatherHeadline,
                reminder: viewModel.weatherReminder,
                secondaryNote: viewModel.secondaryWeatherNote,
                sourceLabel: weatherSourceLabel,
                isAnimationActive: selectedTab == .home
            )

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
            sectionHeader(title: "今日 OOTD", subtitle: viewModel.todayOOTDSnapshot == nil ? "等待设置" : "已保存")

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
                NavigationLink {
                    RecommendationInputView(
                        defaultWeather: currentRecommendationWeather,
                        defaultTemperature: currentRecommendationTemperature,
                        weatherSource: .homeWeatherCard
                    )
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

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "快捷操作", subtitle: "接下来能做什么")

            LazyVGrid(columns: quickActionColumns, spacing: 12) {
                ForEach(viewModel.quickActions) { action in
                    Button {
                        handleQuickAction(action)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.16))
                                Image(systemName: action.symbolName)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(width: 38, height: 38)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(action.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                Text(action.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                }
            }
        }
    }

    private var lightweightOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "轻量概览", subtitle: "一眼知道今天")

            LazyVGrid(columns: overviewColumns, spacing: 12) {
                summaryChip(title: "数字衣橱", value: "\(viewModel.totalItemsText) 件", compact: true)
                summaryChip(title: "近期计划", value: "\(viewModel.upcomingPlanSummaries.count) 条", compact: true)
                summaryChip(title: "已存 OOTD", value: "\(viewModel.savedOutfitsCountText) 套", compact: true)
            }

            ShareLink(
                item: fullDataExportText,
                subject: Text("\(AppReleaseInfo.appName)完整报告"),
                message: Text("包含衣橱、OOTD 和计划的本地数据报告。")
            ) {
                Label("导出完整报告", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .disabled(!hasExportableData)
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.16))
        }
    }

    private var dataBackupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "数据安全", subtitle: "备份与恢复")

            LazyVGrid(columns: overviewColumns, spacing: 12) {
                Button {
                    prepareBackupExport()
                } label: {
                    backupActionCard(
                        title: "导出备份",
                        subtitle: "JSON 文件",
                        systemImage: "externaldrive.badge.plus"
                    )
                }
                .disabled(!hasExportableData)
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)

                Button {
                    showsBackupImporter = true
                } label: {
                    backupActionCard(
                        title: "恢复备份",
                        subtitle: "合并数据",
                        systemImage: "arrow.down.doc"
                    )
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
            }
        }
    }

    private func backupActionCard(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: 36, height: 36)
                .homeCardSurface(weight: .secondary, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
    }

    private var weeklyPlansSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "最近计划摘要", subtitle: "未来几天")

            if viewModel.upcomingPlanSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.upcomingPlansEmptyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        selectedTab = .plans
                    } label: {
                        Label("去创建计划", systemImage: "calendar.badge.plus")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                }
                .padding(18)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            } else {
                ForEach(viewModel.upcomingPlanSummaries) { summary in
                    NavigationLink {
                        PlanDetailView(plan: summary.plan)
                    } label: {
                        upcomingPlanSummaryRow(summary: summary)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
        }
    }

    private var currentRecommendationWeather: RecommendationWeather? {
        viewModel.weather?.kind.recommendationWeather
    }

    private var currentRecommendationTemperature: Int? {
        viewModel.weather?.temperature
    }

    private var weatherSourceLabel: String {
        viewModel.weather?.sourceTitle ?? viewModel.weatherSourceState.sourceLabel
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
        case .locationUnavailable, .forecastUnavailable, .networkUnavailable, .invalidCityName, .cityNotFound:
            viewModel.markForecastUnavailable(error.userMessage)
        }
    }

    private func presentCityWeatherPicker() {
        showsWeatherCityPicker = true
    }

    private var hasExportableData: Bool {
        !items.isEmpty || !outfits.isEmpty || !plans.isEmpty
    }

    private var coreFlowReadiness: WardrobeCoreFlowReadiness {
        WardrobeCoreFlowReadiness.make(items: items, outfits: outfits)
    }

    private var canLoadSampleData: Bool {
        AppReleaseInfo.allowsSampleDataEntry && showsOnboardingSection
    }

    private var fullDataExportText: String {
        WardrobeExporter.fullReport(items: items, outfits: outfits, plans: plans)
    }

    private func prepareBackupExport() {
        do {
            let backup = try WardrobeBackupManager.makeBackupFile(
                items: items,
                outfits: outfits,
                plans: plans
            )
            backupExportDocument = backup.file
            backupExportFilename = backup.filename
            showsBackupExporter = true
        } catch {
            globalFeedback = ActionFeedbackState(
                title: "备份导出失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func handleBackupExportResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success:
            AppHaptics.success()
            globalFeedback = ActionFeedbackState(
                title: "备份已导出",
                message: "JSON 备份文件已保存，可用于之后恢复衣橱、OOTD 和计划。",
                systemImage: "externaldrive.badge.checkmark"
            )
        case .failure(let error):
            globalFeedback = ActionFeedbackState(
                title: "备份导出失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func handleBackupImportResult(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { @MainActor in
                await restoreBackup(from: url)
            }
        case .failure(let error):
            globalFeedback = ActionFeedbackState(
                title: "备份恢复失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    @MainActor
    private func restoreBackup(from url: URL) async {
        do {
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let summary = try WardrobeBackupManager.restore(
                from: data,
                into: modelContext,
                existingItems: items,
                existingOutfits: outfits,
                existingPlans: plans
            )
            let scheduledNotifications = await WardrobeNotificationSynchronizer.synchronizeImportedNotifications(
                summary.plansForNotificationSync
            )
            try modelContext.save()
            syncViewModel()
            AppHaptics.success()
            globalFeedback = ActionFeedbackState(
                title: summary.totalRecordsChanged == 0 ? "备份已读取" : "备份已恢复",
                message: summary.feedbackMessage(scheduledNotifications: scheduledNotifications),
                systemImage: "externaldrive.badge.checkmark"
            )
        } catch {
            globalFeedback = ActionFeedbackState(
                title: "备份恢复失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func handleQuickAction(_ action: HomeDashboardViewModel.QuickAction) {
        AppHaptics.selection()
        switch action.id {
        case .addClothing:
            showsAddClothing = true
        case .recommendOutfit:
            startRecommendationFlow()
        case .createOOTD:
            startCreateOOTDFlow()
        case .createPlan:
            startCreatePlanFlow()
        }
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

    private func startCreatePlanFlow() {
        guard coreFlowReadiness.canCreatePlan else {
            if coreFlowReadiness.canCreateOOTD {
                selectedTab = .ootd
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

        showsCreatePlan = true
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

    private var recommendationPiecesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "推荐单品", subtitle: "OOTD 组成")

            ForEach(viewModel.recommendation.pieces, id: \.id) { item in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(item.tintColor.gradient)
                        .frame(width: 68, height: 68)
                        .overlay {
                            Image(systemName: item.imageSymbol)
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.95))
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.fullDisplaySubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .glassCard(cornerRadius: 28)
            }
        }
    }

    private var ootdBuilderHeroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的 OOTD")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("从现有衣橱保存搭配，设置今日穿什么，再供首页和计划模块读取。")
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

            if coreFlowReadiness.canCreateOOTD {
                ootdTemplateStrip
            }
        }
    }

    private var ootdTemplateStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "快速模板", subtitle: "按场景开局")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(OOTDStarterTemplate.allCases) { template in
                        Button {
                            startCreateOOTDFlow(template: template)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: template.systemImage)
                                    .font(.headline.weight(.semibold))
                                Text(template.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(template.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(width: 156, alignment: .leading)
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

    private var ootdLibraryHealthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "搭配整理", subtitle: ootdLibrarySnapshot.tasks.isEmpty ? "状态良好" : "\(ootdLibrarySnapshot.tasks.count) 项")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ootdMetricChip(title: "全部", value: "\(ootdLibrarySnapshot.outfitCount)", systemImage: "square.grid.2x2")
                ootdMetricChip(title: "已排期", value: "\(ootdLibrarySnapshot.plannedCount)", systemImage: "calendar.badge.checkmark")
                ootdMetricChip(title: "未排期", value: "\(ootdLibrarySnapshot.unplannedCount)", systemImage: "calendar.badge.plus")
                ootdMetricChip(title: "待补齐", value: "\(ootdLibrarySnapshot.incompleteCount)", systemImage: "exclamationmark.triangle")
            }

            if !ootdLibrarySnapshot.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ootdLibrarySnapshot.tasks) { task in
                        Button {
                            handleOOTDLibraryTask(task)
                        } label: {
                            ootdTaskRow(task)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                    }
                }
            }
        }
    }

    private func ootdMetricChip(title: String, value: String, systemImage: String) -> some View {
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

    private func ootdTaskRow(_ task: OOTDLibraryTask) -> some View {
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

    private var todayOOTDSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "今日搭配", subtitle: viewModel.todayOutfit == nil ? "还未设置" : "当前读取中")

            if let todayOutfit = viewModel.todayOutfit {
                NavigationLink {
                    OOTDDetailView(outfit: todayOutfit) {
                        markOutfitAsToday(todayOutfit)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(todayOutfit.title)
                                    .font(.headline)
                                Text(todayOutfit.notes.isEmpty ? todayOutfit.summaryText : todayOutfit.notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Text("今天")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(todayOutfit.orderedItems.prefix(5), id: \.id) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: item.imageSymbol)
                                            .font(.caption.weight(.medium))
                                        Text(item.name)
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
                }
                .buttonStyle(HomePressableButtonStyle())
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
            sectionHeader(title: "已保存搭配", subtitle: ootdListSubtitle)

            if outfits.isEmpty {
                Text("还没有保存的 OOTD。先从衣橱里选单品，保存第一套搭配。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            } else if visibleOOTDOutfits.isEmpty {
                ootdFilterControls
                ootdEmptySearchState
            } else {
                ootdFilterControls

                ForEach(visibleOOTDOutfits, id: \.id) { outfit in
                    NavigationLink {
                        OOTDDetailView(outfit: outfit) {
                            markOutfitAsToday(outfit)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(outfit.title)
                                        .font(.headline)
                                    Text(outfit.notes.isEmpty ? outfit.summaryText : outfit.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if outfit.isToday {
                                    Text("今日")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
                                }
                            }

                            Text(outfit.summaryText)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)

                            if outfit.isIncomplete {
                                Label("缺少：\(outfit.missingSlotTitles.joined(separator: "、"))", systemImage: "exclamationmark.triangle")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(outfit.orderedItems, id: \.id) { item in
                                        HStack(spacing: 8) {
                                            Image(systemName: item.imageSymbol)
                                                .font(.caption.weight(.medium))
                                            Text(item.name)
                                                .font(.caption.weight(.medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                                    }
                                }
                            }

                            HStack {
                                Label("查看详情", systemImage: "arrow.up.right")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if !outfit.isToday {
                                    Text("可设为今日")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(18)
                        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
        }
    }

    private var ootdFilterControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("搜索标题、备注或单品", text: $ootdSearchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)

                if !ootdSearchText.isEmpty {
                    Button {
                        ootdSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空 OOTD 搜索")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(OOTDListFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedOOTDListFilter = filter
                            AppHaptics.selection()
                        } label: {
                            Label(filter.title, systemImage: filter.systemImage)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: selectedOOTDListFilter == filter ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var ootdEmptySearchState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("没有匹配的搭配")
                .font(.headline)
            Text("换个关键词，或切回“全部”查看完整 OOTD 列表。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                ootdSearchText = ""
                selectedOOTDListFilter = .all
            } label: {
                Label("清空筛选", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var atmosphericBackground: some View {
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

            Circle()
                .fill(Color(red: 0.72, green: 0.82, blue: 0.94).opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: 150, y: 110)

            Ellipse()
                .fill(Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.16))
                .frame(width: 320, height: 220)
                .blur(radius: 56)
                .offset(x: 0, y: 260)
        }
    }

    private var quickActionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 112), spacing: 12)]
    }

    private var overviewColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96), spacing: 12)]
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

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func syncViewModel(
        items: [WardrobeItem]? = nil,
        plans: [OutfitPlan]? = nil,
        outfits: [OOTDOutfit]? = nil
    ) {
        viewModel.update(
            items: items ?? self.items,
            plans: plans ?? self.plans,
            outfits: outfits ?? self.outfits
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

private struct WeatherCityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let savedCity: String
    let onSave: (String) -> Void
    let onUseCurrentLocation: () -> Void
    @State private var cityName: String

    init(
        savedCity: String,
        onSave: @escaping (String) -> Void,
        onUseCurrentLocation: @escaping () -> Void
    ) {
        self.savedCity = savedCity
        self.onSave = onSave
        self.onUseCurrentLocation = onUseCurrentLocation
        let initialCity = savedCity.trimmingCharacters(in: .whitespacesAndNewlines)
        _cityName = State(initialValue: initialCity.isEmpty ? "上海" : initialCity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("城市天气") {
                    TextField("城市名称", text: $cityName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("选择城市只是选择天气预报地点，不会让你手动改天气或温度。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        onUseCurrentLocation()
                        dismiss()
                    } label: {
                        Label("使用当前位置天气", systemImage: "location.fill")
                    }
                } footer: {
                    Text("如果定位权限已开启，会优先读取当前位置的真实天气。")
                }
            }
            .navigationTitle("选择天气城市")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("获取天气") {
                        onSave(trimmedCityName)
                        dismiss()
                    }
                    .disabled(trimmedCityName.isEmpty)
                }
            }
        }
    }

    private var trimmedCityName: String {
        cityName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension ContentView {
    enum OOTDListFilter: CaseIterable {
        case all
        case today
        case planned
        case unplanned
        case incomplete

        var title: String {
            switch self {
            case .all:
                "全部"
            case .today:
                "今日"
            case .planned:
                "已排期"
            case .unplanned:
                "未排期"
            case .incomplete:
                "缺失"
            }
        }

        var systemImage: String {
            switch self {
            case .all:
                "square.grid.2x2"
            case .today:
                "sun.max"
            case .planned:
                "calendar.badge.checkmark"
            case .unplanned:
                "calendar.badge.plus"
            case .incomplete:
                "exclamationmark.triangle"
            }
        }
    }

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

    var visibleOOTDOutfits: [OOTDOutfit] {
        outfits.filter { outfit in
            matchesOOTDFilter(outfit) && matchesOOTDSearch(outfit)
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
        let searchableText = ([outfit.title, outfit.notes, outfit.summaryText] + itemFields)
            .joined(separator: " ")
        return searchableText.localizedCaseInsensitiveContains(query)
    }

    func handleOOTDLibraryTask(_ task: OOTDLibraryTask) {
        switch task.kind {
        case .createOOTD:
            startCreateOOTDFlow()
        case .showAll:
            selectedOOTDListFilter = .all
            ootdSearchText = ""
            AppHaptics.selection()
        case .showIncomplete:
            selectedOOTDListFilter = .incomplete
            ootdSearchText = ""
            AppHaptics.selection()
        case .showUnplanned:
            selectedOOTDListFilter = .unplanned
            ootdSearchText = ""
            AppHaptics.selection()
        }
    }

}

struct WardrobeItemCard: View {
    enum Emphasis {
        case carousel
        case grid
    }

    let item: WardrobeItem
    var emphasis: Emphasis = .carousel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(item.tintColor.gradient)
                .frame(height: emphasis == .grid ? 158 : 138)
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
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.96))
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.12)))
                            .padding(10)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(item.category)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.24), in: Capsule())
                        .padding(10)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.compactDisplaySubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !badgeTexts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badgeTexts.prefix(emphasis == .grid ? 2 : 3), id: \.self) { badge in
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                        }
                    }
                }
            }
        }
        .padding(14)
        .homeCardSurface(
            weight: emphasis == .grid ? .secondary : .tertiary,
            cornerRadius: HomeMetrics.secondaryRadius
        )
    }

    private var badgeTexts: [String] {
        var badges = [item.season]
        if let brand = item.trimmedBrand {
            badges.append(brand)
        }
        if let size = item.trimmedSize {
            badges.append(size)
        }
        if let styleTag = item.styleTags.first {
            badges.append(styleTag)
        }
        return badges
    }
}

enum HomeMetrics {
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let primaryRadius: CGFloat = 30
    static let secondaryRadius: CGFloat = 26
    static let innerRadius: CGFloat = 22
    static let pillRadius: CGFloat = 18
    static let primaryCardPadding: CGFloat = 22
    static let secondaryCardPadding: CGFloat = 20
}

enum HomeCardWeight {
    case secondary
    case tertiary
}

extension View {
    func glassCard(cornerRadius: CGFloat, tint: Color = Color.white.opacity(0.32)) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func homeCardSurface(weight: HomeCardWeight, cornerRadius: CGFloat) -> some View {
        modifier(HomeCardSurfaceModifier(weight: weight, cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func homeTabBarGlass() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func homeInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)
                        .overlay {
                            Color.clear
                                .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .rect(cornerRadius: cornerRadius))
                        }
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(tint)
                        }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

struct HomeCardSurfaceModifier: ViewModifier {
    let weight: HomeCardWeight
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let tint: Color = switch weight {
        case .secondary:
            Color.white.opacity(0.18)
        case .tertiary:
            Color.white.opacity(0.10)
        }

        let shadowOpacity: Double = switch weight {
        case .secondary:
            0.09
        case .tertiary:
            0.05
        }

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint)
                    }
                    .overlay(alignment: .topLeading) {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(weight == .secondary ? 0.22 : 0.16),
                                Color.white.opacity(0.06),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(Color.white.opacity(weight == .secondary ? 0.10 : 0.06))
                            .frame(width: 46)
                            .blur(radius: 12)
                            .offset(x: 10)
                    }
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.white.opacity(weight == .secondary ? 0.16 : 0.10))
                            .frame(width: weight == .secondary ? 68 : 54, height: weight == .secondary ? 68 : 54)
                            .blur(radius: 24)
                            .offset(x: 10, y: -12)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 10)
    }
}

struct HomePressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

struct HomeIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .glassCard(cornerRadius: 22, tint: Color.white.opacity(0.20))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
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
