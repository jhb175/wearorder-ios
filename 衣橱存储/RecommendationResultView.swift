import SwiftData
import SwiftUI

struct RecommendationResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var items: [WardrobeItem]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]

    @State private var currentResponse: RecommendationResponse
    @State private var selectedAdjustment: RecommendationAdjustment?

    @State private var feedback: ActionFeedbackState?
    @State private var showsCreatePlan = false
    @State private var plannedOutfitID: PersistentIdentifier?
    @State private var suggestedPlanTitle = "新的穿搭计划"
    @State private var savedOutfitForDetail: OOTDOutfit?

    init(response: RecommendationResponse) {
        _currentResponse = State(initialValue: response)
        _selectedAdjustment = State(initialValue: response.adjustment)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                wardrobeGapSection

                if let emptyStateMessage = currentResponse.emptyStateMessage {
                    emptyStateCard(message: emptyStateMessage)
                } else {
                    ForEach(currentResponse.results) { result in
                        resultCard(result)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(background)
        .navigationTitle("推荐结果")
        .homeInlineNavigationTitle()
        .sheet(isPresented: $showsCreatePlan) {
            NavigationStack {
                CreatePlanView(initialSelectedOutfitID: plannedOutfitID, suggestedTitle: suggestedPlanTitle) { plan, notificationResult in
                    feedback = .planSaved(plan, notificationResult: notificationResult)
                }
            }
        }
        .sheet(item: $savedOutfitForDetail) { outfit in
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: feedback?.id)
    }

    @ViewBuilder
    private var wardrobeGapSection: some View {
        if !currentResponse.wardrobeGaps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("推荐精度建议")
                    .font(.title3.weight(.semibold))

                ForEach(currentResponse.wardrobeGaps) { gap in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: gap.systemImage)
                            .font(.headline)
                            .frame(width: 34, height: 34)
                            .homeCardSurface(weight: .tertiary, cornerRadius: 17)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(gap.title)
                                .font(.subheadline.weight(.semibold))
                            Text(gap.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)
                    }
                    .padding(16)
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本地规则推荐")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(recommendationConditionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !currentResponse.results.isEmpty {
                Label("已生成 \(currentResponse.results.count) 套可执行搭配", systemImage: "checkmark.circle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            adjustmentSection
        }
    }

    @ViewBuilder
    private var adjustmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("二次调整")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RecommendationAdjustment.allCases) { adjustment in
                    let isSelected = selectedAdjustment == adjustment
                    Button {
                        AppHaptics.selection()
                        selectedAdjustment = adjustment
                        regenerateRecommendations(using: adjustment)
                    } label: {
                        Text(adjustment.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(
                        cornerRadius: HomeMetrics.secondaryRadius,
                        tint: isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.12)
                    )
                }
            }

            if let selectedAdjustment {
                Text("当前已按“\(selectedAdjustment.rawValue)”重新生成。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func emptyStateCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("暂时无法生成推荐")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Label("返回调整条件", systemImage: "arrow.left")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
        }
        .padding(20)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func resultCard(_ result: RecommendationResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                    Text(result.reasonSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if let savedStatus = savedStatusText(for: result) {
                        Text(savedStatus)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
                    }

                    if result.usesFavorite {
                        Text("含收藏")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                }
            }

            Text(result.subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            if !result.scoreHighlights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(result.scoreHighlights, id: \.self) { highlight in
                            Text(highlight)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                        }
                    }
                }
            }

            if !result.insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("推荐依据")
                        .font(.subheadline.weight(.semibold))

                    ForEach(result.insights) { insight in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: insight.systemImage)
                                .font(.caption.weight(.semibold))
                                .frame(width: 24, height: 24)
                                .homeCardSurface(weight: .tertiary, cornerRadius: 12)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title)
                                    .font(.caption.weight(.semibold))
                                Text(insight.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(14)
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
            }

            if !result.replacements.isEmpty {
                replacementSection(result.replacements)
            }

            if !result.upgradeTips.isEmpty {
                upgradeTipSection(result.upgradeTips)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(result.orderedItems, id: \.id) { item in
                        WardrobeItemCard(item: item, emphasis: .carousel)
                            .frame(width: 184)
                    }
                }
                .padding(.vertical, 2)
            }

            VStack(spacing: 10) {
                Button {
                    do {
                        let outcome = try saveRecommendation(result, marksAsToday: false)
                        AppHaptics.success()
                        feedback = ActionFeedbackState(
                            title: outcome.inserted ? "已保存为 OOTD" : "已找到已保存 OOTD",
                            message: outcome.inserted ? "这套推荐已加入你的搭配列表。" : "相同单品组合已经存在，这次直接复用原有搭配。",
                            actionTitle: "查看详情",
                            onAction: {
                                savedOutfitForDetail = outcome.outfit
                                feedback = nil
                            }
                        )
                    } catch {
                        showSaveFailure(error)
                    }
                } label: {
                    Label(existingSavedOutfit(for: result) == nil ? "保存为 OOTD" : "查看已保存", systemImage: existingSavedOutfit(for: result) == nil ? "square.and.arrow.down" : "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.2))

                HStack(spacing: 10) {
                    Button {
                        do {
                            let outcome = try saveRecommendation(result, marksAsToday: true)
                            AppHaptics.success()
                            feedback = ActionFeedbackState(
                                title: outcome.inserted ? "已保存并设为今日搭配" : "已设为今日搭配",
                                message: outcome.inserted ? "这套推荐已保存，首页“今日 OOTD”会立即读取。" : "已复用原有搭配，首页“今日 OOTD”会立即读取。"
                            )
                        } catch {
                            showSaveFailure(error)
                        }
                    } label: {
                        Label("设为今日搭配", systemImage: "sun.max")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))

                    Button {
                        do {
                            let outcome = try saveRecommendation(result, marksAsToday: false)
                            AppHaptics.success()
                            plannedOutfitID = outcome.outfit.persistentModelID
                            suggestedPlanTitle = result.title + " · 计划"
                            showsCreatePlan = true
                        } catch {
                            showSaveFailure(error)
                        }
                    } label: {
                        Label("加入计划", systemImage: "calendar.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func replacementSection(_ replacements: [RecommendationReplacement]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("可替换 / 补位")
                .font(.subheadline.weight(.semibold))

            ForEach(replacements) { replacement in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: replacement.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .homeCardSurface(weight: .tertiary, cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(replacement.slotTitle)
                                .font(.caption.weight(.semibold))
                            Text(replacement.replacementItem.compactDisplaySubtitle)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Text("\(replacement.currentItemName) 换成 \(replacement.replacementItem.name)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)

                        Text(replacement.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
                .padding(12)
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.innerRadius)
            }
        }
    }

    private func upgradeTipSection(_ tips: [RecommendationUpgradeTip]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("升级建议")
                .font(.subheadline.weight(.semibold))

            ForEach(tips) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tip.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .homeCardSurface(weight: .tertiary, cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tip.title)
                            .font(.caption.weight(.semibold))
                        Text(tip.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
            }
        }
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    @discardableResult
    private func saveRecommendation(_ result: RecommendationResult, marksAsToday: Bool) throws -> RecommendationSaveOutcome {
        if marksAsToday {
            for outfit in outfits where outfit.isToday {
                outfit.isToday = false
                outfit.updatedAt = .now
            }
        }

        if let existingOutfit = existingSavedOutfit(for: result) {
            if marksAsToday {
                existingOutfit.isToday = true
            }
            existingOutfit.updatedAt = .now
            try modelContext.save()
            return RecommendationSaveOutcome(outfit: existingOutfit, inserted: false)
        }

        let outfit = OOTDOutfit(
            title: result.title,
            notes: result.reasonSummary,
            isToday: marksAsToday,
            topItem: result.topItem,
            bottomItem: result.bottomItem,
            outerwearItem: result.outerwearItem,
            shoesItem: result.shoesItem,
            bagItem: result.bagItem,
            accessoryItem: result.accessoryItem
        )

        modelContext.insert(outfit)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(outfit)
            throw error
        }
        return RecommendationSaveOutcome(outfit: outfit, inserted: true)
    }

    private func showSaveFailure(_ error: Error) {
        feedback = ActionFeedbackState(
            title: "保存失败",
            message: error.localizedDescription,
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    private func savedStatusText(for result: RecommendationResult) -> String? {
        guard let savedOutfit = existingSavedOutfit(for: result) else { return nil }
        return savedOutfit.isToday ? "今日已保存" : "已保存"
    }

    private func existingSavedOutfit(for result: RecommendationResult) -> OOTDOutfit? {
        outfits.first { outfit in
            outfit.topItem?.id == result.topItem.id
            && outfit.bottomItem?.id == result.bottomItem.id
            && outfit.outerwearItem?.id == result.outerwearItem?.id
            && outfit.shoesItem?.id == result.shoesItem?.id
            && outfit.bagItem?.id == result.bagItem?.id
            && outfit.accessoryItem?.id == result.accessoryItem?.id
        }
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

    private var recommendationConditionText: String {
        [
            currentResponse.input.weather?.rawValue ?? "未指定天气",
            currentResponse.input.temperatureCelsius.map { "\($0)°" },
            currentResponse.input.occasion.rawValue,
            currentResponse.input.style.rawValue
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private func regenerateRecommendations(using adjustment: RecommendationAdjustment) {
        currentResponse = RecommendationEngine.generateRecommendations(
            from: items,
            input: currentResponse.input,
            adjustment: adjustment
        )
    }
}

private struct RecommendationSaveOutcome {
    let outfit: OOTDOutfit
    let inserted: Bool
}

#Preview("Recommendation Result") {
    let response = RecommendationEngine.generateRecommendations(
        from: WardrobeMockData.items,
        input: RecommendationInput(weather: .sunny, occasion: .commute, style: .minimal)
    )

    return NavigationStack {
        RecommendationResultView(response: response)
    }
    .modelContainer(WardrobePreviewContainer.shared)
}
