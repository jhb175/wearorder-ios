import SwiftUI

/// Required by App Store guideline 4.0 (generative AI disclosure).
/// Used wherever AI-generated outfit content is shown to the user —
/// generation result cards, OOTDDetailView header, etc.
struct AIDisclosureBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            Text("AI 生成")
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.18))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.blue.opacity(0.30), lineWidth: 0.6)
        )
    }
}

#Preview("Default") {
    AIDisclosureBadge()
        .padding()
}

#Preview("Compact") {
    AIDisclosureBadge(compact: true)
        .padding()
}
