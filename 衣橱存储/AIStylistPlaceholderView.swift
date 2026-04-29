import SwiftUI

struct AIStylistPlaceholderView: View {
    private let capabilities = AIStylistCapability.defaults

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                heroSection
                capabilitySection
                flowSection
            }
            .padding(.horizontal, HomeMetrics.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(AppAdaptiveBackground())
        .navigationTitle("AI 搭配师")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .homeCardSurface(weight: .tertiary, cornerRadius: 20)

                Spacer()

                Text("Pro 内测")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("聊天生成穿搭")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("把天气、场景、心情和目的地交给 AI，再从你的真实衣橱里挑选单品。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                phasePill("局部换单品")
                phasePill("安排未来日期")
                phasePill("旅行搭配")
            }
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.primaryRadius, tint: Color.white.opacity(0.16))
    }

    private var capabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("可落地能力", subtitle: "先预埋入口")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(capabilities) { capability in
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: capability.systemImage)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 34, height: 34)
                            .homeCardSurface(weight: .tertiary, cornerRadius: 16)

                        Text(capability.title)
                            .font(.subheadline.weight(.semibold))
                        Text(capability.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
                }
            }
        }
    }

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("下一阶段接入", subtitle: "会员功能")

            VStack(alignment: .leading, spacing: 12) {
                flowRow(
                    index: "1",
                    title: "输入需求",
                    subtitle: "例如通勤、约会、旅行、心情或指定日期"
                )
                flowRow(
                    index: "2",
                    title: "生成并微调",
                    subtitle: "支持换上衣、外套、鞋履、包袋或配饰"
                )
                flowRow(
                    index: "3",
                    title: "保存到计划",
                    subtitle: "满意后一键保存为 OOTD 或安排到未来某天"
                )
            }
            .padding(16)
            .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func flowRow(index: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(index)
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .homeCardSurface(weight: .tertiary, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
    }

    private func phasePill(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
    }
}

private struct AIStylistCapability: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String

    static let defaults: [AIStylistCapability] = [
        AIStylistCapability(title: "衣橱选品", subtitle: "只从已入库单品里生成搭配", systemImage: "square.grid.2x2"),
        AIStylistCapability(title: "天气联动", subtitle: "结合今日或未来天气建议层次", systemImage: "cloud.sun.fill"),
        AIStylistCapability(title: "局部替换", subtitle: "单独换上装、鞋履、外套或配饰", systemImage: "arrow.triangle.2.circlepath"),
        AIStylistCapability(title: "未来计划", subtitle: "把生成结果安排到指定日期", systemImage: "calendar.badge.plus")
    ]
}

#Preview {
    NavigationStack {
        AIStylistPlaceholderView()
    }
}
