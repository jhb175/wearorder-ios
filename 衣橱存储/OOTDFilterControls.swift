import SwiftUI

struct OOTDFilterControls: View {
    @Binding var searchText: String
    @Binding var listFilter: OOTDListFilter
    @Binding var tagFilter: String?
    @Binding var sortMode: OOTDPresetSortMode
    let availableTags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("搜索标题、备注或单品", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空 OOTD 搜索")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(OOTDListFilter.allCases, id: \.self) { filter in
                        Button {
                            listFilter = filter
                            AppHaptics.selection()
                        } label: {
                            Label(filter.title, systemImage: filter.systemImage)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: listFilter == filter ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            if !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button {
                            tagFilter = nil
                            AppHaptics.selection()
                        } label: {
                            Label("全部标签", systemImage: "tag")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: tagFilter == nil ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )

                        ForEach(availableTags, id: \.self) { tag in
                            Button {
                                tagFilter = tag
                                AppHaptics.selection()
                            } label: {
                                Text(tag)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(
                                weight: tagFilter == tag ? .secondary : .tertiary,
                                cornerRadius: HomeMetrics.pillRadius
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(OOTDPresetSortMode.allCases, id: \.self) { mode in
                        Button {
                            sortMode = mode
                            AppHaptics.selection()
                        } label: {
                            Label(mode.title, systemImage: mode.systemImage)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(
                            weight: sortMode == mode ? .secondary : .tertiary,
                            cornerRadius: HomeMetrics.pillRadius
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
