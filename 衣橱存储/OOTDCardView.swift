import SwiftUI

struct OOTDCardView<Destination: View>: View {
    let recommendation: OutfitRecommendation
    let destination: Destination

    init(
        recommendation: OutfitRecommendation,
        @ViewBuilder destination: () -> Destination
    ) {
        self.recommendation = recommendation
        self.destination = destination()
    }

    var body: some View {
        ZStack {
            ootdAtmosphere
            ootdGlassOverlay

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(recommendation.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryText)

                    Text(recommendation.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recommendation.styleTags, id: \.self) { tag in
                                styleTag(tag)
                            }
                        }
                    }
                }

                outfitArtwork

                Text(recommendation.reason)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(secondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recommendation.pieces.prefix(4), id: \.id) { piece in
                            HStack(spacing: 8) {
                                Image(systemName: piece.imageSymbol)
                                    .font(.caption.weight(.medium))
                                Text(piece.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(primaryText.opacity(0.92))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .overlay {
                                        Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                                    }
                            }
                        }
                    }
                }

                NavigationLink {
                    destination
                } label: {
                    HStack {
                        Text("查看搭配详情")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .background {
                    RoundedRectangle(cornerRadius: HomeMetrics.innerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay {
                            RoundedRectangle(cornerRadius: HomeMetrics.innerRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.9)
                        }
                }
            }
            .padding(HomeMetrics.primaryCardPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: HomeMetrics.primaryRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HomeMetrics.primaryRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.06), radius: 18, y: 10)
    }

    private var outfitArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(outfitArtworkGradient)

            if artworkPieces.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white.opacity(0.94))
                    Text("今日搭配")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.84))
                }
            } else {
                if artworkPieces.count <= 2 {
                    HStack(spacing: 10) {
                        ForEach(Array(artworkPieces.enumerated()), id: \.element.id) { index, piece in
                            artworkTile(
                                piece,
                                height: 226,
                                showsExtraCount: index == artworkPieces.count - 1 && extraPieceCount > 0
                            )
                        }
                    }
                    .padding(12)
                } else {
                    LazyVGrid(columns: artworkColumns, spacing: 10) {
                        ForEach(Array(artworkPieces.enumerated()), id: \.element.id) { index, piece in
                            artworkTile(
                                piece,
                                height: 108,
                                showsExtraCount: index == artworkPieces.count - 1 && extraPieceCount > 0
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.26),
                        .clear,
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 32, height: 32)
                    .blur(radius: 10)
                    .offset(x: 5, y: 8)
            }
    }

    private var artworkPieces: [WardrobeItem] {
        Array(recommendation.pieces.prefix(4))
    }

    private var extraPieceCount: Int {
        max(0, recommendation.pieces.count - artworkPieces.count)
    }

    private var artworkColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private func artworkTile(_ piece: WardrobeItem, height: CGFloat, showsExtraCount: Bool) -> some View {
        WardrobeItemImageView(
            item: piece,
            cornerRadius: 20,
            symbolFont: .title2.weight(.semibold),
            contentMode: .fit
        )
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.68))
        }
        .overlay(alignment: .bottomLeading) {
            Text(piece.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule().strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
                        }
                }
                .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            if showsExtraCount {
                Text("+\(extraPieceCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(Color.white.opacity(0.86))
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.34), lineWidth: 0.8)
                            }
                    }
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
        }
    }

    private var outfitArtworkGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.74, green: 0.78, blue: 0.84),
                Color(red: 0.89, green: 0.90, blue: 0.93),
                Color(red: 0.96, green: 0.95, blue: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var ootdAtmosphere: some View {
        RoundedRectangle(cornerRadius: HomeMetrics.primaryRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .overlay(alignment: .trailing) {
                ZStack {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 140
                            )
                        )
                        .frame(width: 240, height: 230)
                        .offset(x: 28, y: -10)

                    Ellipse()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 92, height: 250)
                        .rotationEffect(.degrees(12))
                        .opacity(0.48)
                        .offset(x: 30)
                }
            }
    }

    private var ootdGlassOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 82)

            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 74)
        }
    }

    private var primaryText: Color {
        Color.primary.opacity(0.94)
    }

    private var secondaryText: Color {
        Color.secondary.opacity(0.96)
    }

    private func styleTag(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    }
            }
    }
}

#Preview("OOTD Card") {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.95, blue: 0.97),
                Color(red: 0.90, green: 0.93, blue: 0.97),
                Color(red: 0.97, green: 0.93, blue: 0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        OOTDCardView(
            recommendation: OutfitRecommendation(
                title: "通勤推荐",
                subtitle: "低饱和、线条干净，适合需要效率感的工作日。",
                reason: "优先组合中性色和轻结构单品，保持专业但不生硬。",
                pieces: WardrobeMockData.items.prefix(4).map { $0 },
                styleTags: ["通勤", "极简", "轻结构"]
            ),
            destination: { Text("OOTD Detail") }
        )
        .padding(20)
    }
}
