import SwiftUI

struct OOTDEmptySearchState: View {
    let onClearFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("没有匹配的预设")
                .font(.headline)
            Text("换个关键词，或切回“全部”查看完整 OOTD 预设。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: onClearFilters) {
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
}
