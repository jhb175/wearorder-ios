import SwiftUI

struct OOTDTemplateStrip: View {
    let onSelect: (OOTDStarterTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "快速模板", subtitle: "按场景开局")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(OOTDStarterTemplate.allCases) { template in
                        Button {
                            onSelect(template)
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
}

