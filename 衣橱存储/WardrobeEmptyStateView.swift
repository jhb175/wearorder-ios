import SwiftUI

struct WardrobeEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String
    let actionSystemImage: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .homeCardSurface(weight: .tertiary, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                action()
            } label: {
                Label(actionTitle, systemImage: actionSystemImage)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(HomePressableButtonStyle())
            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }
}

#Preview {
    WardrobeEmptyStateView(
        title: "还没有衣物",
        message: "先添加第一件衣物，后续搭配和计划都会从这里读取。",
        systemImage: "tshirt.fill",
        actionTitle: "添加衣物",
        actionSystemImage: "plus.viewfinder"
    ) {}
    .padding()
}
