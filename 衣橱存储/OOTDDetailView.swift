import SwiftData
import SwiftUI

struct OOTDDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    let outfit: OOTDOutfit
    var onSetToday: (() -> Void)? = nil
    @State private var showsCreatePlan = false
    @State private var showsEditSheet = false
    @State private var showsDeleteConfirmation = false
    @State private var feedback: ActionFeedbackState?
    @State private var duplicatedOutfitForDetail: OOTDOutfit?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                piecesSection
                notesSection
                linkedPlansSection
                deletionImpactSection
                actionSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .background(background)
        .navigationTitle("OOTD 详情")
        .homeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: outfitExportText,
                    subject: Text("OOTD 搭配详情"),
                    message: Text("来自\(AppReleaseInfo.appName)的本地搭配详情。")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("导出 OOTD")
            }
        }
        .sheet(isPresented: $showsCreatePlan) {
            NavigationStack {
                CreatePlanView(initialSelectedOutfitID: outfit.persistentModelID, suggestedTitle: outfit.title + " · 计划") { plan, notificationResult in
                    feedback = .planSaved(plan, notificationResult: notificationResult)
                }
            }
        }
        .sheet(isPresented: $showsEditSheet) {
            NavigationStack {
                CreateOOTDView(editingOutfit: outfit) { updatedOutfit in
                    feedback = ActionFeedbackState(
                        title: "已更新 OOTD",
                        message: "“\(updatedOutfit.title)”的搭配内容已经保存。"
                    )
                }
            }
        }
        .sheet(item: $duplicatedOutfitForDetail) { outfit in
            NavigationStack {
                OOTDDetailView(outfit: outfit)
            }
        }
        .safeAreaInset(edge: .bottom) {
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
                .padding(.bottom, 12)
            }
        }
        .alert("删除这套 OOTD？", isPresented: $showsDeleteConfirmation) {
            Button("删除", role: .destructive) {
                deleteOutfit()
            }
            Button("取消", role: .cancel) {
            }
        } message: {
            Text(deletionImpact.alertMessage)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(outfit.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text(outfit.createdAt, format: .dateTime.month().day().year())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if outfit.isToday {
                        heroBadge("今日搭配")
                    }

                    if outfit.source != .manual {
                        heroBadge(outfit.sourceDisplayTitle)
                    }
                }
            }

            Text(outfit.notes.isEmpty ? outfit.summaryText : outfit.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(outfit.summaryText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(16)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius)

            if outfit.isIncomplete {
                Text("这套搭配当前有缺失单品：\(outfit.missingSlotTitles.joined(separator: "、"))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            }
        }
    }

    private func heroBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
    }

    private var piecesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "所含单品", subtitle: "\(outfit.orderedItems.count) 件")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(outfitSlots, id: \.title) { slot in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(slot.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        if let item = slot.item {
                            WardrobeItemCard(item: item, emphasis: .grid)
                        } else {
                            RoundedRectangle(cornerRadius: HomeMetrics.secondaryRadius, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 178)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "square.dashed")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                        Text("未选择")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if !outfit.notes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "备注", subtitle: "简单说明")
                Text(outfit.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            }
        }
    }

    private var linkedPlansSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "关联计划", subtitle: linkedPlans.isEmpty ? "暂无引用" : "\(linkedPlans.count) 条")

            if linkedPlans.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有计划引用这套 OOTD 预设。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        showsCreatePlan = true
                    } label: {
                        Label("排到日期", systemImage: "calendar.badge.plus")
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
                ForEach(linkedPlans, id: \.id) { plan in
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
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
                                Text(plan.occasion)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                if plan.reminderEnabled, let reminderDate = plan.reminderDate {
                                    Text("提醒 · \(reminderDate.formatted(.dateTime.hour().minute()))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                setAsToday()
            } label: {
                Label(outfit.isToday ? "当前已是今日搭配" : "设为今日搭配", systemImage: outfit.isToday ? "checkmark.circle.fill" : "sun.max")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(
                cornerRadius: HomeMetrics.secondaryRadius,
                tint: outfit.isToday ? Color.white.opacity(0.26) : Color.white.opacity(0.18)
            )
            .disabled(outfit.isToday)

            Button {
                showsCreatePlan = true
            } label: {
                Label("排到日期", systemImage: "calendar.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.16))

            Button {
                duplicateOutfit()
            } label: {
                Label("复制为新搭配", systemImage: "plus.square.on.square")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.16))

            HStack(spacing: 10) {
                Button {
                    showsEditSheet = true
                } label: {
                    Label("编辑搭配", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.16))

                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.12))
            }
        }
    }

    private var deletionImpactSection: some View {
        DeletionImpactCard(summary: deletionImpact)
    }

    private var linkedPlans: [OutfitPlan] {
        plans
            .filter { $0.linkedOutfit?.id == outfit.id }
            .sorted { $0.date < $1.date }
    }

    private var outfitExportText: String {
        WardrobeExporter.outfitReport(for: outfit, linkedPlans: linkedPlans)
    }

    private var deleteMessage: String {
        deletionImpact.alertMessage
    }

    private var deletionImpact: DeletionImpactSummary {
        DeletionImpactSummary.outfit(
            outfitTitle: outfit.title,
            linkedPlanCount: linkedPlans.count,
            isToday: outfit.isToday
        )
    }

    private func setAsToday() {
        if let onSetToday {
            onSetToday()
        } else {
            for existing in outfits where existing.isToday {
                existing.isToday = false
                existing.updatedAt = .now
            }
            outfit.isToday = true
            outfit.updatedAt = .now
        }
        do {
            try modelContext.save()
            AppHaptics.success()
            feedback = ActionFeedbackState(
                title: "已设为今日搭配",
                message: "首页“今日 OOTD”会立即同步这套搭配。"
            )
        } catch {
            feedback = ActionFeedbackState(
                title: "保存失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func deleteOutfit() {
        for plan in linkedPlans {
            plan.outfitSummary = outfit.summaryText
            plan.linkedOutfit = nil
            plan.updatedAt = .now
        }
        modelContext.delete(outfit)
        do {
            try modelContext.save()
            AppHaptics.warning()
            dismiss()
        } catch {
            feedback = ActionFeedbackState(
                title: "删除失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func duplicateOutfit() {
        let duplicatedOutfit = OOTDOutfit(
            title: outfit.title + " 副本",
            notes: outfit.notes,
            isToday: false,
            sourceKind: outfit.sourceKind,
            aiPrompt: outfit.aiPrompt,
            aiRecommendationReason: outfit.aiRecommendationReason,
            aiWeatherSummary: outfit.aiWeatherSummary,
            aiGeneratedAt: outfit.aiGeneratedAt,
            aiModelIdentifier: outfit.aiModelIdentifier,
            topItem: outfit.topItem,
            bottomItem: outfit.bottomItem,
            outerwearItem: outfit.outerwearItem,
            shoesItem: outfit.shoesItem,
            bagItem: outfit.bagItem,
            accessoryItem: outfit.accessoryItem
        )
        modelContext.insert(duplicatedOutfit)
        do {
            try modelContext.save()
            AppHaptics.success()
            feedback = ActionFeedbackState(
                title: "已复制为新搭配",
                message: "可以直接编辑这套副本，作为另一套 OOTD 使用。",
                actionTitle: "查看副本",
                onAction: {
                    duplicatedOutfitForDetail = duplicatedOutfit
                    feedback = nil
                }
            )
        } catch {
            modelContext.delete(duplicatedOutfit)
            feedback = ActionFeedbackState(
                title: "复制失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private var outfitSlots: [(title: String, item: WardrobeItem?)] {
        [
            ("上装", outfit.topItem),
            ("下装", outfit.bottomItem),
            ("外套", outfit.outerwearItem),
            ("鞋子", outfit.shoesItem),
            ("包", outfit.bagItem),
            ("配饰", outfit.accessoryItem)
        ]
    }

    private var background: some View {
        AppAdaptiveBackground()
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
}

#Preview("OOTD Detail") {
    NavigationStack {
        OOTDDetailView(outfit: WardrobeMockData.outfits.first.flatMap { seed in
            let items = Dictionary(uniqueKeysWithValues: WardrobeMockData.items.map { ($0.name, $0) })
            return OOTDOutfit(
                title: seed.title,
                notes: seed.notes,
                isToday: seed.isToday,
                topItem: seed.topName.flatMap { items[$0] },
                bottomItem: seed.bottomName.flatMap { items[$0] },
                outerwearItem: seed.outerwearName.flatMap { items[$0] },
                shoesItem: seed.shoesName.flatMap { items[$0] },
                bagItem: seed.bagName.flatMap { items[$0] },
                accessoryItem: seed.accessoryName.flatMap { items[$0] }
            )
        } ?? OOTDOutfit(title: "预览搭配", notes: "", isToday: false))
    }
    .modelContainer(WardrobePreviewContainer.shared)
}
