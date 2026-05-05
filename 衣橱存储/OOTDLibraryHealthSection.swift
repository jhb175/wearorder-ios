import SwiftUI

struct OOTDLibraryHealthSection: View {
    let snapshot: OOTDLibrarySnapshot
    let onTaskTap: (OOTDLibraryTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(
                title: "预设整理",
                subtitle: snapshot.tasks.isEmpty ? "状态良好" : "\(snapshot.tasks.count) 项"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                OOTDMetricChip(title: "全部预设", value: "\(snapshot.outfitCount)", systemImage: "square.grid.2x2")
                OOTDMetricChip(title: "已排期", value: "\(snapshot.plannedCount)", systemImage: "calendar.badge.checkmark")
                OOTDMetricChip(title: "未排期", value: "\(snapshot.unplannedCount)", systemImage: "calendar.badge.plus")
                OOTDMetricChip(title: "待补齐", value: "\(snapshot.incompleteCount)", systemImage: "exclamationmark.triangle")
            }

            if !snapshot.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(snapshot.tasks) { task in
                        Button {
                            onTaskTap(task)
                        } label: {
                            OOTDTaskRow(task: task)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                    }
                }
            }
        }
    }
}

private struct OOTDMetricChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.headline.monospacedDigit().weight(.semibold))
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }
}

private struct OOTDTaskRow: View {
    let task: OOTDLibraryTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: task.systemImage)
                .font(.headline)
                .frame(width: 34, height: 34)
                .homeCardSurface(weight: .tertiary, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                Text(task.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 10)
        }
        .padding(16)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }
}
