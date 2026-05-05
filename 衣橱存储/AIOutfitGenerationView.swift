import SwiftData
import SwiftUI

/// Replaces the legacy `AIStylistPlaceholderView` placeholder.
/// Sprint 3.1 MVP — single-shot prompt → outfit → save flow.
@MainActor
struct AIOutfitGenerationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WardrobeItem.createdAt, order: .reverse) private var items: [WardrobeItem]
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var savedOutfits: [OOTDOutfit]

    @State private var userPrompt: String = ""
    @State private var phase: Phase = .idle
    @State private var feedback: ActionFeedbackState?

    let weather: HomeDashboardViewModel.WeatherSnapshot?
    private let generator = AIOutfitGenerator()

    enum Phase: Equatable {
        case idle
        case generating
        case result(AIOutfitGenerator.GenerationResult)
        case error(String)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroBanner
                weatherChip
                promptInputCard
                generateButton

                switch phase {
                case .idle:
                    EmptyView()
                case .generating:
                    loadingCard
                case .result(let result):
                    resultCard(result)
                case .error(let message):
                    errorCard(message)
                }
            }
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(AppAdaptiveBackground())
        .navigationTitle("AI 搭配师")
        .navigationBarTitleDisplayMode(.inline)
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
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Sections

    private var heroBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .homeCardSurface(weight: .tertiary, cornerRadius: 18)

            VStack(alignment: .leading, spacing: 6) {
                Text("从你的衣橱里生成穿搭")
                    .font(.title3.weight(.semibold))
                Text("结合天气和心情，从已有单品里挑一套合适的搭配。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            AIDisclosureBadge(compact: true)
        }
        .padding(16)
        .glassCard(cornerRadius: HomeMetrics.primaryRadius, tint: Color.white.opacity(0.16))
    }

    private var weatherChip: some View {
        HStack(spacing: 8) {
            Image(systemName: weather?.kind.symbolName ?? "thermometer.medium")
                .font(.caption.weight(.bold))
            Text(weatherSummary)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
    }

    private var promptInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("想去哪里、做什么？")
                .font(.subheadline.weight(.semibold))
            TextField(
                "例：今天去咖啡馆 / 想穿轻松一点 / 通勤偏正式",
                text: $userPrompt,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCardSurface(weight: .tertiary, cornerRadius: 14)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await runGeneration() }
        } label: {
            HStack(spacing: 8) {
                if case .generating = phase {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(phase == .generating ? "AI 正在思考…" : "生成搭配")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(HomePressableButtonStyle())
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.blue.opacity(0.36))
        .disabled(phase == .generating || items.isEmpty)
        .opacity((phase == .generating || items.isEmpty) ? 0.6 : 1.0)
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("AI 正在结合天气和你的衣橱挑选单品…")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func resultCard(_ result: AIOutfitGenerator.GenerationResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.resolved.title)
                        .font(.title3.weight(.semibold))
                    Text(result.weatherSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                AIDisclosureBadge(compact: true)
            }

            Text(result.resolved.reason)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(AIWardrobeContext.slotKeys, id: \.self) { slotKey in
                    if let item = result.resolved.items[slotKey] {
                        slotRow(slotKey: slotKey, item: item)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    saveResult(result, marksAsToday: false)
                } label: {
                    Label("保存为 OOTD", systemImage: "square.and.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.20))

                Button {
                    saveResult(result, marksAsToday: true)
                } label: {
                    Label("设为今日", systemImage: "sun.max")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.blue.opacity(0.30))
            }

            Button {
                Task { await runGeneration() }
            } label: {
                Label("再生成一套", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
        }
        .padding(16)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private func slotRow(slotKey: String, item: WardrobeItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.imageSymbol)
                .font(.caption.weight(.semibold))
                .frame(width: 30, height: 30)
                .homeCardSurface(weight: .tertiary, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(slotDisplayTitle(for: slotKey))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(item.colorName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .homeCardSurface(weight: .tertiary, cornerRadius: 14)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("AI 暂时无法生成")
                    .font(.subheadline.weight(.semibold))
            }
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await runGeneration() }
            } label: {
                Label("重试", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
        }
        .padding(14)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    // MARK: - Actions

    @MainActor
    private func runGeneration() async {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let promptToUse = trimmed.isEmpty ? "今天合适的搭配" : trimmed

        phase = .generating
        do {
            let result = try await generator.generate(
                userPrompt: promptToUse,
                weather: weather,
                items: items
            )
            phase = .result(result)
        } catch let error as AIOutfitGenerator.GenerationError {
            phase = .error(error.errorDescription ?? "AI 当前不可用，请稍后再试。")
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func saveResult(_ result: AIOutfitGenerator.GenerationResult, marksAsToday: Bool) {
        if marksAsToday {
            for outfit in savedOutfits where outfit.isToday {
                outfit.isToday = false
                outfit.updatedAt = .now
            }
        }

        let outfit = OOTDOutfit(
            title: result.resolved.title,
            notes: result.resolved.reason,
            isToday: marksAsToday,
            sourceKind: OOTDSourceKind.ai.rawValue,
            aiPrompt: result.promptUsed,
            aiRecommendationReason: result.resolved.reason,
            aiWeatherSummary: result.weatherSummary,
            aiGeneratedAt: .now,
            aiModelIdentifier: result.modelIdentifier,
            topItem: result.resolved.topItem,
            bottomItem: result.resolved.bottomItem,
            outerwearItem: result.resolved.outerwearItem,
            shoesItem: result.resolved.shoesItem,
            bagItem: result.resolved.bagItem,
            accessoryItem: result.resolved.accessoryItem
        )

        modelContext.insert(outfit)
        do {
            try modelContext.save()
            AppHaptics.success()
            feedback = ActionFeedbackState(
                title: marksAsToday ? "已保存并设为今日搭配" : "已保存为 OOTD",
                message: marksAsToday ? "首页「今日 OOTD」会立即读取这套 AI 搭配。" : "这套 AI 搭配已加入你的搭配列表。",
                systemImage: marksAsToday ? "sun.max.fill" : "checkmark.circle.fill"
            )
        } catch {
            modelContext.delete(outfit)
            feedback = ActionFeedbackState(
                title: "保存失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    // MARK: - Helpers

    private var weatherSummary: String {
        guard let weather else { return "天气数据未就绪" }
        return "\(weather.kind.rawValue) \(weather.temperature)°C · 体感 \(weather.apparentTemperature)°"
    }

    private func slotDisplayTitle(for slotKey: String) -> String {
        switch slotKey {
        case "top": return "上装"
        case "bottom": return "下装"
        case "outerwear": return "外套"
        case "shoes": return "鞋"
        case "bag": return "包"
        case "accessory": return "配饰"
        default: return slotKey
        }
    }
}

#Preview {
    NavigationStack {
        AIOutfitGenerationView(weather: nil)
    }
}
