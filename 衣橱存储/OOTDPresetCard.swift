import SwiftUI

struct OOTDPresetCard: View {
    let outfit: OOTDOutfit
    let onMarkAsToday: () -> Void
    let onScheduleToDate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(outfit.title)
                        .font(.headline)
                    Text(outfit.notes.isEmpty ? outfit.summaryText : outfit.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(outfit.isToday ? "今日" : "预设")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
            }

            if !outfit.orderedItems.isEmpty {
                OOTDPresetPreview(outfit: outfit)
            }

            Text(outfit.summaryText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            if outfit.isIncomplete {
                Label("缺少：\(outfit.missingSlotTitles.joined(separator: "、"))", systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if !outfit.presetTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(outfit.presetTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(outfit.orderedItems, id: \.id) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.imageSymbol)
                                .font(.caption.weight(.medium))
                            Text(item.name)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                }
            }

            HStack(spacing: 10) {
                NavigationLink {
                    OOTDDetailView(outfit: outfit) {
                        onMarkAsToday()
                    }
                } label: {
                    Label("详情", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)

                Button {
                    onScheduleToDate()
                    AppHaptics.selection()
                } label: {
                    Label("安排到日期", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .secondary, cornerRadius: HomeMetrics.pillRadius)
            }

            if !outfit.isToday {
                Button {
                    onMarkAsToday()
                    AppHaptics.selection()
                } label: {
                    Label("设为今日 OOTD", systemImage: "sun.max")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(HomePressableButtonStyle())
                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }
}

private struct OOTDPresetPreview: View {
    let outfit: OOTDOutfit

    var body: some View {
        let previewItems = Array(outfit.orderedItems.prefix(4))

        HStack(spacing: 10) {
            ForEach(previewItems, id: \.id) { item in
                WardrobeItemImageView(item: item, cornerRadius: 16, symbolFont: .title3.weight(.semibold))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottomLeading) {
                        Text(item.category)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(.black.opacity(0.32))
                            }
                            .padding(6)
                    }
            }

            if previewItems.count < 4 {
                ForEach(0..<(4 - previewItems.count), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.12))
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
