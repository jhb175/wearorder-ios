import SwiftUI

struct WardrobeOnboardingView: View {
    let canLoadSampleData: Bool
    let onAction: (WardrobeOnboardingAction) -> Void
    @State private var selectedPage = 0

    private let pages = WardrobeOnboardingPage.allCases

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        onboardingPage(page)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 14) {
                    pageIndicator

                    Button {
                        if selectedPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                selectedPage += 1
                            }
                        } else {
                            onAction(.addClothing)
                        }
                    } label: {
                        Label(primaryActionTitle, systemImage: primaryActionSymbol)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.22))

                    HStack(spacing: 10) {
                        if canLoadSampleData && AppReleaseInfo.allowsSampleDataEntry {
                            Button {
                                onAction(.loadSampleData)
                            } label: {
                                Label("载入示例", systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                        }

                        Button {
                            onAction(.dismiss)
                        } label: {
                            Text("稍后")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(onboardingBackground)
            .navigationTitle("开始使用")
            .homeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onAction(.dismiss)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭引导")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onAction(.openSettings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("打开设置")
                }
            }
        }
    }

    private var primaryActionTitle: String {
        selectedPage < pages.count - 1 ? "下一步" : "添加第一件衣物"
    }

    private var primaryActionSymbol: String {
        selectedPage < pages.count - 1 ? "arrow.right" : "plus.viewfinder"
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? Color.primary.opacity(0.70) : Color.primary.opacity(0.18))
                    .frame(width: index == selectedPage ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedPage)
            }
        }
    }

    private func onboardingPage(_ page: WardrobeOnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 24)

            Image(systemName: page.systemImage)
                .font(.system(size: 36, weight: .semibold))
                .frame(width: 72, height: 72)
                .homeCardSurface(weight: .secondary, cornerRadius: 28)

            VStack(alignment: .leading, spacing: 10) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(page.checkpoints, id: \.self) { checkpoint in
                    Label(checkpoint, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var onboardingBackground: some View {
        AppAdaptiveBackground()
    }
}

private enum WardrobeOnboardingPage: CaseIterable {
    case wardrobe
    case ootd
    case planner

    var title: String {
        switch self {
        case .wardrobe:
            "先记录常穿衣物"
        case .ootd:
            "保存稳定搭配"
        case .planner:
            "把出门计划排好"
        }
    }

    var message: String {
        switch self {
        case .wardrobe:
            "从上装、下装和鞋履开始，少量高质量数据就能让后续推荐更可靠。"
        case .ootd:
            "把常穿组合存成 OOTD，首页、推荐结果和计划都能继续复用。"
        case .planner:
            "给未来日期绑定搭配，必要时开启本地提醒，再定期导出备份。"
        }
    }

    var systemImage: String {
        switch self {
        case .wardrobe:
            "square.grid.2x2.fill"
        case .ootd:
            "wand.and.stars"
        case .planner:
            "calendar.badge.clock"
        }
    }

    var checkpoints: [String] {
        switch self {
        case .wardrobe:
            ["先添加 3 件以上核心单品", "照片会在保存前压缩", "标签和备注可之后补充"]
        case .ootd:
            ["上装和下装是推荐基础", "可设置一套今日搭配", "不完整搭配会被健康检查提示"]
        case .planner:
            ["计划可以关联 OOTD", "提醒只保存在本机", "JSON 备份可用于恢复数据"]
        }
    }
}

#Preview {
    WardrobeOnboardingView(canLoadSampleData: true) { _ in }
}
