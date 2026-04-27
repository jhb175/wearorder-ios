import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

struct ClothingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]
    let item: WardrobeItem
    var onDeleted: ((String) -> Void)? = nil
    @State private var showsEditSheet = false
    @State private var showsDeleteConfirmation = false
    @State private var showsCreateOOTD = false
    @State private var feedback: ActionFeedbackState?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ClothingImagePreview(imageData: item.imageData, imageSymbol: item.imageSymbol, tintColor: item.tintColor)
                    .frame(height: 320)

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.title2.weight(.bold))
                    Text(item.fullDisplaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                detailCard(title: "风格标签", value: item.styleTags.isEmpty ? "暂未填写" : item.styleTags.joined(separator: " · "))
                detailCard(title: "购买与尺码", value: item.purchaseDetailText)
                detailCard(title: "保养备注", value: item.trimmedCareNotes ?? "暂未填写")
                detailCard(title: "备注", value: item.notes.isEmpty ? "暂未填写" : item.notes)
                detailCard(title: "记录信息", value: recordInfoText)
                usageSummarySection
                linkedOutfitsSection
                linkedPlansSection
                deletionImpactSection

                HStack(spacing: 12) {
                    favoriteAction
                    editAction
                    addToOOTDAction
                }

                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("删除衣物", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.12))
            }
            .padding(24)
        }
        .background(detailBackground)
        .navigationTitle("衣物详情")
        .homeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: itemExportText,
                    subject: Text("衣物详情"),
                    message: Text("来自\(AppReleaseInfo.appName)的本地衣物详情。")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("导出衣物详情")
            }
        }
        .sheet(isPresented: $showsEditSheet) {
            EditClothingView(item: item) { updatedItem in
                feedback = ActionFeedbackState(
                    title: "已保存修改",
                    message: "“\(updatedItem.name)”的资料已经更新。"
                )
            }
        }
        .sheet(isPresented: $showsCreateOOTD) {
            NavigationStack {
                CreateOOTDView(prefilledItem: item) { outfit in
                    feedback = ActionFeedbackState(
                        title: outfit.isToday ? "已加入 OOTD 并设为今日搭配" : "已加入 OOTD",
                        message: "“\(item.name)”已经带入“\(outfit.title)”。"
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let feedback {
                ActionFeedbackBanner(
                    title: feedback.title,
                    message: feedback.message,
                    systemImage: feedback.systemImage,
                    actionTitle: feedback.actionTitle,
                    onAction: feedback.onAction,
                    onDismiss: { self.feedback = nil }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .alert("删除这件衣物？", isPresented: $showsDeleteConfirmation) {
            Button("删除", role: .destructive) {
                deleteItem()
            }
            Button("取消", role: .cancel) {
            }
        } message: {
            Text(deletionImpact.alertMessage)
        }
    }

    @ViewBuilder
    private func detailCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var usageSummarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            usageMetricCard(title: "关联搭配", value: "\(linkedOOTDOutfits.count)", systemImage: "wand.and.stars")
            usageMetricCard(title: "关联计划", value: "\(linkedPlans.count)", systemImage: "calendar")
            usageMetricCard(title: "收藏状态", value: item.isFavorite ? "已收藏" : "未收藏", systemImage: item.isFavorite ? "heart.fill" : "heart")
            usageMetricCard(title: "图片状态", value: item.imageData == nil ? "缺图片" : "有图片", systemImage: item.imageData == nil ? "photo.badge.exclamationmark" : "photo")
            usageMetricCard(title: "资料状态", value: item.needsDetailCompletion ? "待补全" : "完整", systemImage: item.needsDetailCompletion ? "checklist" : "checkmark.seal")
        }
    }

    private func usageMetricCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.82))
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var deletionImpactSection: some View {
        DeletionImpactCard(summary: deletionImpact)
    }

    @ViewBuilder
    private var linkedOutfitsSection: some View {
        if linkedOOTDOutfits.isEmpty {
            detailCard(title: "关联搭配", value: "这件衣物目前没有被搭配引用。")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("关联搭配")
                    .font(.headline)

                Text(deleteAssociationMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(linkedOOTDOutfits, id: \.id) { outfit in
                    NavigationLink {
                        OOTDDetailView(outfit: outfit)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: outfit.isToday ? "sun.max.fill" : "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 30, height: 30)
                                .homeCardSurface(weight: .tertiary, cornerRadius: 15)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(outfit.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(outfit.summaryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
            .padding(18)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    @ViewBuilder
    private var linkedPlansSection: some View {
        if linkedPlans.isEmpty {
            detailCard(title: "关联计划", value: "还没有计划通过 OOTD 使用这件衣物。")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("关联计划")
                    .font(.headline)

                Text("这些计划绑定的 OOTD 中包含“\(item.name)”。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(linkedPlans, id: \.id) { plan in
                    NavigationLink {
                        PlanDetailView(plan: plan)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.date, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(plan.date, format: .dateTime.day())
                                    .font(.title2.weight(.bold))
                            }
                            .frame(width: 52)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(plan.linkedOutfit?.title ?? plan.outfitSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if plan.reminderEnabled, let reminderDate = plan.reminderDate {
                                    Text("提醒 · \(reminderDate.formatted(.dateTime.hour().minute()))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                }
            }
            .padding(18)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    private var addToOOTDAction: some View {
        Button {
            showsCreateOOTD = true
        } label: {
            Label("加入 OOTD", systemImage: "wand.and.stars")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(HomePressableButtonStyle())
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
    }

    private var favoriteAction: some View {
        Button {
            item.isFavorite.toggle()
            item.updatedAt = .now
            do {
                try modelContext.save()
                AppHaptics.selection()
                feedback = ActionFeedbackState(
                    title: item.isFavorite ? "已加入收藏" : "已取消收藏",
                    message: item.isFavorite ? "这件衣物会在收藏筛选里优先显示。" : "这件衣物已从收藏筛选中移除。",
                    systemImage: item.isFavorite ? "heart.fill" : "heart.slash"
                )
            } catch {
                item.isFavorite.toggle()
                feedback = ActionFeedbackState(
                    title: "收藏状态保存失败",
                    message: error.localizedDescription,
                    systemImage: "exclamationmark.triangle.fill"
                )
            }
        } label: {
            Label(item.isFavorite ? "已收藏" : "收藏", systemImage: item.isFavorite ? "heart.fill" : "heart")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(HomePressableButtonStyle())
        .glassCard(
            cornerRadius: HomeMetrics.secondaryRadius,
            tint: item.isFavorite ? Color.white.opacity(0.24) : Color.white.opacity(0.18)
        )
    }

    private var editAction: some View {
        Button {
            showsEditSheet = true
        } label: {
            Label("编辑", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(HomePressableButtonStyle())
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
    }

    private var linkedOOTDOutfits: [OOTDOutfit] {
        outfits.filter { outfit in
            usesItem(outfit: outfit)
        }
    }

    private var linkedPlansCount: Int {
        linkedPlans.count
    }

    private var linkedPlans: [OutfitPlan] {
        plans.filter { plan in
            guard let linkedOutfit = plan.linkedOutfit else { return false }
            return linkedOOTDOutfits.contains { $0.id == linkedOutfit.id }
        }
        .sorted { $0.date < $1.date }
    }

    private var itemExportText: String {
        WardrobeExporter.itemReport(
            for: item,
            linkedOutfits: linkedOOTDOutfits,
            linkedPlans: linkedPlans
        )
    }

    private var recordInfoText: String {
        var parts = [
            "创建：\(item.createdAt.formatted(.dateTime.year().month().day().hour().minute()))"
        ]

        if let updatedAt = item.updatedAt {
            parts.append("更新：\(updatedAt.formatted(.dateTime.year().month().day().hour().minute()))")
        }

        if let imageData = item.imageData {
            parts.append("图片：\(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
        } else {
            parts.append("图片：使用默认图标")
        }

        return parts.joined(separator: "\n")
    }

    private var deleteAssociationMessage: String {
        deletionImpact.message
    }

    private var deletionImpact: DeletionImpactSummary {
        DeletionImpactSummary.wardrobeItem(
            itemName: item.name,
            linkedOutfitCount: linkedOOTDOutfits.count,
            linkedPlanCount: linkedPlansCount
        )
    }

    private func deleteItem() {
        for outfit in linkedOOTDOutfits {
            outfit.removeReferences(to: item)
        }

        let deletedName = item.name
        modelContext.delete(item)
        do {
            try modelContext.save()
            AppHaptics.warning()
            onDeleted?(deletedName)
            dismiss()
        } catch {
            feedback = ActionFeedbackState(
                title: "删除失败",
                message: error.localizedDescription,
                systemImage: "exclamationmark.triangle.fill"
            )
        }
    }

    private func usesItem(outfit: OOTDOutfit) -> Bool {
        if outfit.topItem?.id == item.id { return true }
        if outfit.bottomItem?.id == item.id { return true }
        if outfit.outerwearItem?.id == item.id { return true }
        if outfit.shoesItem?.id == item.id { return true }
        if outfit.bagItem?.id == item.id { return true }
        if outfit.accessoryItem?.id == item.id { return true }
        return false
    }

    private var detailBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 0.99),
                Color(red: 0.93, green: 0.95, blue: 0.98),
                Color(red: 0.96, green: 0.95, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ClothingImagePreview: View {
    let imageData: Data?
    let imageSymbol: String
    let tintColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(tintColor.gradient)
            .overlay {
                if let imageData, let image = PlatformImage(data: imageData) {
                    #if canImport(UIKit)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                    #elseif canImport(AppKit)
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                    #endif
                } else {
                    Image(systemName: imageSymbol)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

#Preview("Clothing Detail") {
    NavigationStack {
        ClothingDetailView(item: WardrobeMockData.items[0])
    }
    .modelContainer(WardrobePreviewContainer.shared)
}
