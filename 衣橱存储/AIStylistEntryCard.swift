import SwiftUI

struct AIStylistEntryCard: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 38, height: 38)
                .homeCardSurface(weight: .tertiary, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("AI 搭配师")
                        .font(.subheadline.weight(.semibold))
                    Text("Pro")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                }
                Text("聊天生成 OOTD，支持局部换单品和安排未来计划。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.secondaryRadius)
    }
}
