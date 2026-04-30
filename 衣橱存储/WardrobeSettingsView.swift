import AuthenticationServices
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct WardrobeSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    @AppStorage(WardrobeOnboardingState.storageKey) private var hasSeenOnboarding = false
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.chinese.rawValue
    @AppStorage(WardrobePersistentStore.cloudKitFallbackFlagKey) private var isUsingLocalCloudKitFallback = false
    @State private var showsBackupExporter = false
    @State private var showsBackupImporter = false
    @State private var showsOnboarding = false
    @State private var showsAddClothing = false
    @State private var showsResetConfirmation = false
    @State private var backupExportDocument = WardrobeBackupFile()
    @State private var backupExportFilename = "wardrobe-backup.json"
    @State private var notificationSnapshot = WardrobeNotificationAuditSnapshot.loading
    @State private var isRepairingData = false
    @State private var feedback: ActionFeedbackState?
    @StateObject private var appleIDAccountManager = AppleIDAccountManager()

    private var healthSnapshot: WardrobeDataHealthSnapshot {
        WardrobeDataHealthSnapshot.make(items: items, outfits: outfits, plans: plans)
    }

    private var dataRepairPreview: WardrobeDataRepairSummary {
        WardrobeDataRepair.preview(items: items, outfits: outfits, plans: plans)
    }

    private var hasExportableData: Bool {
        !items.isEmpty || !outfits.isEmpty || !plans.isEmpty
    }

    private var currentAppLanguage: AppLanguage {
        AppLanguage.value(for: appLanguageRawValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    settingsHeroSection
                    accountSection
                    languageSection
                    onboardingSection
                    dataHealthSection
                    backupSection
                    notificationSection
                    if AppReleaseInfo.allowsAIStylistEntry {
                        aiMembershipSection
                    }
                    privacySection
                    if AppReleaseInfo.allowsSampleDataEntry {
                        sampleDataSection
                    }
                    dangerZoneSection
                }
                .padding(.horizontal, HomeMetrics.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .background(settingsBackground)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refreshNotificationSnapshot() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(HomeIconButtonStyle())
                    .accessibilityLabel("重新检查")
                }
            }
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
        .sheet(isPresented: $showsOnboarding) {
            WardrobeOnboardingView(
                canLoadSampleData: canLoadSampleData,
                onAction: handleOnboardingAction
            )
        }
        .sheet(isPresented: $showsAddClothing) {
            AddClothingView { item in
                feedback = ActionFeedbackState(
                    title: "已保存衣物",
                    message: "“\(item.name)”已经加入数字衣橱。"
                )
            }
        }
        .sheet(isPresented: $showsResetConfirmation) {
            WardrobeResetConfirmationView(
                itemCount: items.count,
                outfitCount: outfits.count,
                planCount: plans.count,
                onCancel: {
                    showsResetConfirmation = false
                },
                onConfirm: {
                    showsResetConfirmation = false
                    Task { await resetAllLocalData() }
                }
            )
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
        .task {
            await refreshNotificationSnapshot()
            await appleIDAccountManager.refreshCredentialState()
        }
        .onChange(of: plans) { _, _ in
            Task { await refreshNotificationSnapshot() }
        }
    }

    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "首次引导", subtitle: hasSeenOnboarding ? "已完成" : "未完成")

            Button {
                showsOnboarding = true
            } label: {
                settingsActionRow(
                    title: "查看首次使用引导",
                    subtitle: "从衣物、OOTD、计划和备份开始建立完整流程",
                    systemImage: "sparkles.rectangle.stack"
                )
            }
            .buttonStyle(HomePressableButtonStyle())

            Button {
                hasSeenOnboarding = false
                feedback = ActionFeedbackState(
                    title: "已重置首次引导",
                    message: "当衣橱为空时，下次打开 App 会再次显示引导。",
                    systemImage: "arrow.clockwise"
                )
            } label: {
                settingsActionRow(
                    title: "重置引导状态",
                    subtitle: "清除已完成标记，空衣橱时可再次显示引导",
                    systemImage: "arrow.counterclockwise"
                )
            }
            .buttonStyle(HomePressableButtonStyle())
        }
    }

    private var settingsHeroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("运营中心")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("集中管理本地数据、备份恢复、通知状态和隐私说明。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                metricTile(title: "衣物", value: "\(items.count)")
                metricTile(title: "OOTD", value: "\(outfits.count)")
                metricTile(title: "计划", value: "\(plans.count)")
                metricTile(title: "照片", value: healthSnapshot.totalPhotoStorageText)
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "账号", subtitle: appleIDAccountManager.credentialStatus.title)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: appleIDAccountManager.session == nil ? "person.crop.circle.badge.plus" : "person.crop.circle.fill.badge.checkmark")
                        .font(.headline)
                        .foregroundStyle(appleIDAccountManager.session == nil ? Color.secondary : Color.green)
                        .frame(width: 38, height: 38)
                        .homeCardSurface(weight: .tertiary, cornerRadius: 19)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(appleIDAccountManager.session?.displayName ?? "使用 Apple ID 登录")
                            .font(.headline)
                        Text(accountStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }

                if appleIDAccountManager.session == nil {
                    SignInWithAppleButton(.signIn) { request in
                        appleIDAccountManager.configure(request)
                    } onCompletion: { result in
                        handleAppleIDSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .whiteOutline : .black)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: HomeMetrics.pillRadius, style: .continuous))
                    .accessibilityLabel("使用 Apple ID 登录")
                } else {
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await appleIDAccountManager.refreshCredentialState()
                                feedback = ActionFeedbackState(
                                    title: "账号状态已检查",
                                    message: appleIDAccountManager.credentialStatus.subtitle,
                                    systemImage: "checkmark.seal.fill"
                                )
                            }
                        } label: {
                            Label("检查状态", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)

                        Button(role: .destructive) {
                            appleIDAccountManager.signOutLocal()
                            feedback = ActionFeedbackState(
                                title: "已退出本机账号",
                                message: "仅清除了本机 Apple ID 登录状态，不会删除衣橱数据。",
                                systemImage: "person.crop.circle.badge.minus"
                            )
                        } label: {
                            Label("退出本机", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                }
            }
            .padding(16)
            .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    private var dataHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "数据健康", subtitle: healthSnapshot.statusTitle)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: healthSnapshot.issues.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(healthSnapshot.issues.isEmpty ? .green : .orange)
                        .frame(width: 32, height: 32)
                        .homeCardSurface(weight: .tertiary, cornerRadius: 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(healthSnapshot.statusTitle)
                            .font(.headline)
                        Text(healthSnapshot.statusSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)

                if healthSnapshot.issues.isEmpty {
                    Text("保持定期备份，就能比较安心地继续扩展衣橱数据。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                } else {
                    ForEach(healthSnapshot.issues) { issue in
                        healthIssueRow(issue)
                    }
                }

                if dataRepairPreview.hasChanges {
                    Button {
                        Task { await repairData() }
                    } label: {
                        settingsActionRow(
                            title: isRepairingData ? "正在自动修复" : "自动修复可处理问题",
                            subtitle: dataRepairPreview.feedbackMessage,
                            systemImage: "wand.and.stars"
                        )
                    }
                    .disabled(isRepairingData)
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "备份与迁移", subtitle: "JSON + 报告")

            Button {
                prepareBackupExport()
            } label: {
                settingsActionRow(
                    title: "导出 JSON 备份",
                    subtitle: "保留衣物、照片、OOTD、计划和关联关系",
                    systemImage: "externaldrive.badge.plus"
                )
            }
            .disabled(!hasExportableData)
            .buttonStyle(HomePressableButtonStyle())

            Button {
                showsBackupImporter = true
            } label: {
                settingsActionRow(
                    title: "恢复 JSON 备份",
                    subtitle: "按 UUID 合并数据，不会清空现有记录",
                    systemImage: "arrow.down.doc"
                )
            }
            .buttonStyle(HomePressableButtonStyle())

            ShareLink(
                item: WardrobeExporter.fullReport(items: items, outfits: outfits, plans: plans),
                subject: Text("\(AppReleaseInfo.appName)完整报告"),
                message: Text("包含衣橱、OOTD 和计划的本地数据报告。")
            ) {
                settingsActionRow(
                    title: "分享完整文本报告",
                    subtitle: "适合人工核对，不用于恢复数据",
                    systemImage: "square.and.arrow.up"
                )
            }
            .disabled(!hasExportableData)
            .buttonStyle(HomePressableButtonStyle())
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "通知检查", subtitle: notificationSnapshot.statusText)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: notificationSnapshot.systemImage)
                        .font(.headline)
                        .foregroundStyle(notificationSnapshot.needsAttention ? .orange : .green)
                        .frame(width: 34, height: 34)
                        .homeCardSurface(weight: .tertiary, cornerRadius: 17)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(notificationSnapshot.title)
                            .font(.headline)
                        Text(notificationSnapshot.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await refreshNotificationSnapshot() }
                    } label: {
                        Label("重新检查", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)

                    if notificationSnapshot.authorizationDenied {
                        Button {
                            AppSettings.open()
                        } label: {
                            Label("去设置", systemImage: "gear")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                }
            }
            .padding(16)
            .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    private var aiMembershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "AI 会员", subtitle: "Pro 内测")

            NavigationLink {
                AIStylistPlaceholderView()
            } label: {
                settingsActionRow(
                    title: "AI 搭配师",
                    subtitle: "即将支持聊天搭配、局部换单品和未来计划",
                    systemImage: "sparkles"
                )
            }
            .buttonStyle(HomePressableButtonStyle())

            settingsActionRow(
                title: "会员解锁预留",
                subtitle: "正式版本会接入 App 内购买和 AI 使用额度",
                systemImage: "crown.fill"
            )
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(
                title: "隐私与支持",
                subtitle: AppReleaseInfo.isPublicReleaseContactConfigured ? "本地优先" : "待补链接"
            )

            NavigationLink {
                PrivacyNoticeView()
            } label: {
                settingsActionRow(
                    title: "查看隐私说明",
                    subtitle: "当前版本不接入广告追踪，不上传衣橱数据",
                    systemImage: "hand.raised.fill"
                )
            }
            .buttonStyle(HomePressableButtonStyle())

            releaseContactStatusRow
            releaseURLRow(
                title: "公开隐私政策",
                configuredSubtitle: "打开公开隐私政策页面",
                missingSubtitle: "需要配置公开 HTTPS 隐私政策链接",
                systemImage: "lock.shield.fill",
                url: AppReleaseInfo.privacyPolicyURL
            )
            releaseURLRow(
                title: "用户支持页面",
                configuredSubtitle: "打开公开用户支持页面",
                missingSubtitle: "需要配置公开 HTTPS 支持页面",
                systemImage: "questionmark.circle.fill",
                url: AppReleaseInfo.supportURL
            )
            releaseEmailRow

            if isUsingLocalCloudKitFallback {
                settingsActionRow(
                    title: "iCloud 同步暂不可用",
                    subtitle: "当前已自动切换到本地存储，衣橱可继续使用；请检查 Apple ID、iCloud 和 CloudKit 配置后重启 App。",
                    systemImage: "icloud.slash.fill"
                )
            }

            settingsActionRow(
                title: "本地隐私承诺",
                subtitle: "Apple ID 账号只保存在本机 Keychain，不接入广告追踪，不上传衣橱数据",
                systemImage: "checkmark.shield.fill"
            )
        }
    }

    private var sampleDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "演示数据", subtitle: canLoadSampleData ? "可载入" : "仅空衣橱")

            Button {
                loadSampleData()
            } label: {
                settingsActionRow(
                    title: "载入示例衣橱",
                    subtitle: canLoadSampleData ? "用于快速预览完整流程" : "已有真实数据时禁用，避免污染衣橱",
                    systemImage: "sparkles"
                )
            }
            .disabled(!canLoadSampleData)
            .buttonStyle(HomePressableButtonStyle())
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "日期与系统格式", subtitle: currentAppLanguage.displayName)

            Picker("日期语言", selection: $appLanguageRawValue) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)

            Label("当前切换只影响日期、日历、时间等系统格式；App 文案保持中文。完整多语言会在后续版本单独上线。", systemImage: "globe.asia.australia.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(title: "危险操作", subtitle: hasExportableData ? "需确认" : "无数据")

            Button {
                showsResetConfirmation = true
            } label: {
                settingsActionRow(
                    title: "清空本地衣橱数据",
                    subtitle: hasExportableData ? "会删除衣物、OOTD、计划，并移除计划提醒" : "当前没有可清空的数据",
                    systemImage: "trash"
                )
            }
            .disabled(!hasExportableData)
            .buttonStyle(HomePressableButtonStyle())
        }
    }

    private var accountStatusMessage: String {
        if let session = appleIDAccountManager.session {
            return "\(session.detailText) · \(appleIDAccountManager.credentialStatus.subtitle)"
        }

        return appleIDAccountManager.credentialStatus.subtitle
    }

    private func handleAppleIDSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch appleIDAccountManager.completeSignIn(with: result) {
        case .success(let session):
            feedback = ActionFeedbackState(
                title: "Apple ID 登录成功",
                message: "已为“\(session.displayName)”保存本机账号状态。",
                systemImage: "person.crop.circle.fill.badge.checkmark"
            )
        case .failure(let message):
            feedback = ActionFeedbackState(
                title: "Apple ID 登录未完成",
                message: message,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private var canLoadSampleData: Bool {
        AppReleaseInfo.allowsSampleDataEntry && items.isEmpty && outfits.isEmpty && plans.isEmpty
    }

    private var settingsBackground: some View {
        AppAdaptiveBackground()
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
            feedback = ActionFeedbackState(
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
            feedback = ActionFeedbackState(
                title: "备份已导出",
                message: "JSON 文件已保存，可用于之后恢复衣橱数据。",
                systemImage: "externaldrive.badge.checkmark"
            )
        case .failure(let error):
            feedback = ActionFeedbackState(
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
            feedback = ActionFeedbackState(
                title: "备份恢复失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    @MainActor
    private func restoreBackup(from url: URL) async {
        var restoredImageFileNamesForRollback: [String] = []
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
            restoredImageFileNamesForRollback = summary.imageFileNamesForRollback
            try modelContext.save()
            for fileName in summary.imageFileNamesForCleanup {
                WardrobeImageFileStore.shared.remove(fileName: fileName)
            }
            let scheduledNotifications = await WardrobeNotificationSynchronizer.synchronizeImportedNotifications(
                summary.plansForNotificationSync
            )
            try modelContext.save()
            await refreshNotificationSnapshot()
            AppHaptics.success()
            feedback = ActionFeedbackState(
                title: summary.totalRecordsChanged == 0 ? "备份已读取" : "备份已恢复",
                message: summary.feedbackMessage(scheduledNotifications: scheduledNotifications),
                systemImage: "externaldrive.badge.checkmark"
            )
        } catch {
            for fileName in restoredImageFileNamesForRollback {
                WardrobeImageFileStore.shared.remove(fileName: fileName)
            }
            modelContext.rollback()
            feedback = ActionFeedbackState(
                title: "备份恢复失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func loadSampleData() {
        guard canLoadSampleData else {
            feedback = ActionFeedbackState(
                title: "已有衣橱数据",
                message: "示例数据只会在完全空白的新衣橱里载入。",
                systemImage: "info.circle.fill"
            )
            return
        }

        do {
            let summary = WardrobeSampleDataLoader.insertSampleData(into: modelContext)
            try modelContext.save()
            AppHaptics.success()
            feedback = ActionFeedbackState(
                title: "已载入示例衣橱",
                message: "新增 \(summary.itemCount) 件衣物、\(summary.outfitCount) 套 OOTD 和 \(summary.planCount) 条计划。",
                systemImage: "sparkles"
            )
        } catch {
            feedback = ActionFeedbackState(
                title: "示例数据载入失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    @MainActor
    private func repairData() async {
        guard !isRepairingData else { return }
        isRepairingData = true
        defer { isRepairingData = false }

        do {
            let summary = WardrobeDataRepair.apply(items: items, outfits: outfits, plans: plans)
            for plan in plans where !plan.reminderEnabled {
                await PlannerNotificationManager.removeNotification(for: plan)
            }
            try modelContext.save()
            await refreshNotificationSnapshot()
            AppHaptics.success()
            feedback = ActionFeedbackState(
                title: summary.hasChanges ? "数据已修复" : "无需修复",
                message: summary.feedbackMessage,
                systemImage: summary.hasChanges ? "wand.and.stars" : "checkmark.seal.fill"
            )
        } catch {
            feedback = ActionFeedbackState(
                title: "数据修复失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func handleOnboardingAction(_ action: WardrobeOnboardingAction) {
        hasSeenOnboarding = true
        showsOnboarding = false

        switch action {
        case .addClothing:
            showsAddClothing = true
        case .loadSampleData:
            loadSampleData()
        case .openSettings, .dismiss:
            break
        }
    }

    @MainActor
    private func resetAllLocalData() async {
        let plansToRemoveNotificationsFor = plans
        let imageFileNamesToRemove = items.flatMap { item in
            [item.imageFileName, item.thumbnailFileName].compactMap { $0 }
        }

        do {
            for plan in plans {
                modelContext.delete(plan)
            }
            for outfit in outfits {
                modelContext.delete(outfit)
            }
            for item in items {
                modelContext.delete(item)
            }

            try modelContext.save()
            for fileName in Set(imageFileNamesToRemove) {
                WardrobeImageFileStore.shared.remove(fileName: fileName)
            }
            for plan in plansToRemoveNotificationsFor {
                await PlannerNotificationManager.removeNotification(for: plan)
            }
            await refreshNotificationSnapshot()
            AppHaptics.warning()
            feedback = ActionFeedbackState(
                title: "本地数据已清空",
                message: "衣物、OOTD、计划和对应提醒都已从本机移除。",
                systemImage: "trash"
            )
        } catch {
            modelContext.rollback()
            feedback = ActionFeedbackState(
                title: "清空失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func refreshNotificationSnapshot() async {
        notificationSnapshot = .loading
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pendingRequests = await center.pendingNotificationRequests()
        notificationSnapshot = WardrobeNotificationAuditSnapshot.make(
            settings: settings,
            pendingRequests: pendingRequests,
            plans: plans
        )
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
    }

    private var releaseContactStatusRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: AppReleaseInfo.isPublicReleaseContactConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppReleaseInfo.isPublicReleaseContactConfigured ? .green : .orange)
                .frame(width: 34, height: 34)
                .homeCardSurface(weight: .tertiary, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppReleaseInfo.releaseContactStatusTitle)
                    .font(.subheadline.weight(.semibold))
                Text(AppReleaseInfo.releaseContactStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    @ViewBuilder
    private func releaseURLRow(
        title: String,
        configuredSubtitle: String,
        missingSubtitle: String,
        systemImage: String,
        url: URL?
    ) -> some View {
        if let url {
            Link(destination: url) {
                settingsActionRow(
                    title: title,
                    subtitle: configuredSubtitle,
                    systemImage: systemImage
                )
            }
            .buttonStyle(HomePressableButtonStyle())
        } else {
            settingsActionRow(
                title: "\(title)待配置",
                subtitle: missingSubtitle,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    @ViewBuilder
    private var releaseEmailRow: some View {
        if let supportMailURL = AppReleaseInfo.supportMailURL {
            Link(destination: supportMailURL) {
                settingsActionRow(
                    title: "联系支持邮箱",
                    subtitle: AppReleaseInfo.supportEmail,
                    systemImage: "envelope.fill"
                )
            }
            .buttonStyle(HomePressableButtonStyle())
        } else {
            settingsActionRow(
                title: "支持邮箱待配置",
                subtitle: "需要填写可收信的开发者支持邮箱",
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func settingsSectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func settingsActionRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 34, height: 34)
                .homeCardSurface(weight: .tertiary, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func healthIssueRow(_ issue: WardrobeDataHealthIssue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.severity.systemImage)
                .font(.headline)
                .foregroundStyle(issue.severity.tint)
                .frame(width: 34, height: 34)
                .homeCardSurface(weight: .tertiary, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 5) {
                Text(issue.title)
                    .font(.subheadline.weight(.semibold))
                Text(issue.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(issue.actionHint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(issue.severity.tint)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }
}

private struct PrivacyNoticeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(AppReleaseInfo.appName)隐私说明")
                    .font(.title2.weight(.bold))

                privacyParagraph("当前版本支持使用 Apple ID 登录。App 会把 Apple 返回的用户标识，以及用户同意提供的邮箱和姓名保存在本机 Keychain，用于本机账号状态、后续会员和 AI 功能识别。")
                privacyParagraph("衣物、OOTD、计划和照片默认保存在设备本地。开启 iCloud 的设备会通过 Apple CloudKit 将衣物元数据、OOTD 和计划同步到用户自己的 iCloud 私有数据库；开发者不会通过自有服务器读取这些内容。")
                privacyParagraph("App 可能请求相册权限用于选择衣物照片、请求相机权限用于拍摄衣物照片、请求通知权限用于发送穿搭计划提醒、请求定位权限用于获取本地天气预报。拒绝权限不会影响基础记录功能。")
                privacyParagraph("天气功能会在授权后通过 Apple WeatherKit 使用当前位置经纬度获取当日预报；选择城市天气时，会用系统地理编码将城市名称转换为坐标后查询 Apple Weather。天气请求不会发送衣橱、照片、OOTD 或计划内容。")
                privacyParagraph("当前版本不接入广告追踪，不出售用户数据。CloudKit 一期只同步结构化衣橱数据；衣物原图仍保存在本机 App 沙盒和用户主动导出的备份中。后续如果加入远程 AI 图片识别、订阅或第三方 SDK，需要同步更新隐私说明、公开隐私政策和 App Store Connect 隐私标签。")
            }
            .padding(24)
        }
        .background(AppAdaptiveBackground())
        .navigationTitle("隐私说明")
        .homeInlineNavigationTitle()
    }

    private func privacyParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }
}

private struct WardrobeResetConfirmationView: View {
    let itemCount: Int
    let outfitCount: Int
    let planCount: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var confirmationText = ""

    private var canConfirm: Bool {
        WardrobeDestructiveActionGuard.canConfirmReset(confirmationText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("确认清空本地数据")
                        .font(.title2.weight(.bold))

                    Text("这个操作会删除本机保存的衣物、OOTD、计划和计划提醒。已经导出的备份文件不会受影响。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        resetMetric(title: "衣物", value: "\(itemCount)")
                        resetMetric(title: "OOTD", value: "\(outfitCount)")
                        resetMetric(title: "计划", value: "\(planCount)")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("输入“\(WardrobeDestructiveActionGuard.resetConfirmationPhrase)”以继续")
                            .font(.subheadline.weight(.semibold))
                        TextField(WardrobeDestructiveActionGuard.resetConfirmationPhrase, text: $confirmationText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
                    }

                    Button(role: .destructive) {
                        onConfirm()
                    } label: {
                        Label("确认清空", systemImage: "trash")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(!canConfirm)
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(canConfirm ? 0.18 : 0.10))
                }
                .padding(24)
            }
            .background(AppAdaptiveBackground())
            .navigationTitle("清空数据")
            .homeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func resetMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
    }
}

private struct WardrobeNotificationAuditSnapshot {
    let authorizationStatus: UNAuthorizationStatus?
    let enabledReminderCount: Int
    let invalidReminderCount: Int
    let pendingPlanNotificationCount: Int
    let orphanPendingNotificationCount: Int

    static let loading = WardrobeNotificationAuditSnapshot(
        authorizationStatus: nil,
        enabledReminderCount: 0,
        invalidReminderCount: 0,
        pendingPlanNotificationCount: 0,
        orphanPendingNotificationCount: 0
    )

    var title: String {
        guard let authorizationStatus else { return "正在检查通知状态" }
        if authorizationStatus == .denied {
            return "通知权限未开启"
        }
        if invalidReminderCount > 0 {
            return "有提醒需要修正"
        }
        if enabledReminderCount > pendingPlanNotificationCount {
            return "部分提醒未同步"
        }
        return "通知状态正常"
    }

    var message: String {
        guard authorizationStatus != nil else {
            return "正在读取系统通知授权和待发送提醒。"
        }

        let base = "已开启提醒 \(enabledReminderCount) 条，系统待发送 \(pendingPlanNotificationCount) 条。"
        if authorizationDenied {
            return "\(base) 请到系统设置允许通知后，再回到计划里重新开启提醒。"
        }
        if invalidReminderCount > 0 {
            return "\(base) 其中 \(invalidReminderCount) 条提醒时间为空或已过期。"
        }
        if orphanPendingNotificationCount > 0 {
            return "\(base) 另外发现 \(orphanPendingNotificationCount) 条未匹配到当前计划的待发送提醒。"
        }
        return base
    }

    var statusText: String {
        guard let authorizationStatus else { return "检查中" }
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return needsAttention ? "需关注" : "正常"
        case .notDetermined:
            return "未请求"
        case .denied:
            return "未授权"
        @unknown default:
            return "未知"
        }
    }

    var systemImage: String {
        needsAttention ? "bell.badge.fill" : "bell.and.waves.left.and.right.fill"
    }

    var authorizationDenied: Bool {
        authorizationStatus == .denied
    }

    var needsAttention: Bool {
        guard let authorizationStatus else { return false }
        return authorizationStatus == .denied ||
        invalidReminderCount > 0 ||
        enabledReminderCount > pendingPlanNotificationCount
    }

    @MainActor
    static func make(
        settings: UNNotificationSettings,
        pendingRequests: [UNNotificationRequest],
        plans: [OutfitPlan],
        now: Date = .now
    ) -> WardrobeNotificationAuditSnapshot {
        let planNotificationIdentifiers = Set(plans.map { PlannerNotificationManager.identifier(for: $0) })
        let pendingPlannerIdentifiers = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix("planner-") }

        let invalidReminderCount = plans.filter { plan in
            guard plan.reminderEnabled else { return false }
            guard let reminderDate = plan.reminderDate else { return true }
            return reminderDate <= now
        }
        .count

        return WardrobeNotificationAuditSnapshot(
            authorizationStatus: settings.authorizationStatus,
            enabledReminderCount: plans.filter(\.reminderEnabled).count,
            invalidReminderCount: invalidReminderCount,
            pendingPlanNotificationCount: pendingPlannerIdentifiers.filter(planNotificationIdentifiers.contains).count,
            orphanPendingNotificationCount: pendingPlannerIdentifiers.filter { !planNotificationIdentifiers.contains($0) }.count
        )
    }
}

private extension WardrobeDataHealthSeverity {
    var systemImage: String {
        switch self {
        case .critical:
            "exclamationmark.octagon.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .info:
            "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .critical:
            .red
        case .warning:
            .orange
        case .info:
            .blue
        }
    }
}

#Preview {
    WardrobeSettingsView()
        .modelContainer(WardrobePreviewContainer.shared)
}
