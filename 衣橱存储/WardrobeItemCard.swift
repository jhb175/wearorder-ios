import SwiftUI

struct WardrobeItemCard: View {
    enum Emphasis {
        case carousel
        case grid
    }

    let item: WardrobeItem
    var emphasis: Emphasis = .carousel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WardrobeItemImageView(
                item: item,
                cornerRadius: 24,
                symbolFont: .system(size: 30, weight: .semibold)
            )
                .frame(height: emphasis == .grid ? 158 : 138)
                .overlay(alignment: .topTrailing) {
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.96))
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.12)))
                            .padding(10)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(item.category)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.24), in: Capsule())
                        .padding(10)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.compactDisplaySubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !badgeTexts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badgeTexts.prefix(emphasis == .grid ? 2 : 3), id: \.self) { badge in
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                        }
                    }
                }
            }
        }
        .padding(14)
        .homeCardSurface(
            weight: emphasis == .grid ? .secondary : .tertiary,
            cornerRadius: HomeMetrics.secondaryRadius
        )
    }

    private var badgeTexts: [String] {
        var badges = [item.season]
        if let brand = item.trimmedBrand {
            badges.append(brand)
        }
        if let size = item.trimmedSize {
            badges.append(size)
        }
        if let styleTag = item.styleTags.first {
            badges.append(styleTag)
        }
        return badges
    }
}
