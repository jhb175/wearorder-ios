import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: OutfitPlan
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]

    @State private var title: String
    @State private var occasion: String
    @State private var date: Date
    @State private var notes: String
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var selectedOutfitID: PersistentIdentifier?
    @State private var showsDeleteConfirmation = false
    @State private var isSaving = false
    @State private var feedback: ActionFeedbackState?

    init(plan: OutfitPlan) {
        self.plan = plan
        _title = State(initialValue: plan.title)
        _occasion = State(initialValue: plan.occasion)
        _date = State(initialValue: plan.date)
        _notes = State(initialValue: plan.notes)
        _reminderEnabled = State(initialValue: plan.reminderEnabled)
        _reminderTime = State(initialValue: plan.reminderDate ?? Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: plan.date) ?? plan.date)
        _selectedOutfitID = State(initialValue: plan.linkedOutfit?.persistentModelID)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                planInfoSection
                sameDayPlansSection
                outfitSelectionSection
                linkedOutfitSection
                notesSection
                reminderSection
                deletionImpactSection
                actionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .background(background)
        .navigationTitle("计划详情")
        .homeInlineNavigationTitle()
        .alert("删除这条计划？", isPresented: $showsDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text(deletionImpact.alertMessage)
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
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(displayTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(date.formatted(.dateTime.year().month().day().weekday(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let reminderDate = plan.reminderDate, plan.reminderEnabled {
                Text("提醒时间 · \(reminderDate.formatted(.dateTime.hour().minute()))")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if !sameDayPlans.isEmpty {
                Label("同日还有 \(sameDayPlans.count) 条计划", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var planInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "计划信息", subtitle: "可编辑")

            textField(title: "计划标题", text: $title, prompt: "例如：周三通勤")
            textField(title: "场景", text: $occasion, prompt: "例如：办公室 / 约会 / 周末")

            VStack(alignment: .leading, spacing: 8) {
                Text("计划日期")
                    .font(.subheadline.weight(.semibold))

                DatePicker("计划日期", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .padding(12)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
            }
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    @ViewBuilder
    private var sameDayPlansSection: some View {
        if !sameDayPlans.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "同日安排", subtitle: "\(sameDayPlans.count) 条")

                Text("这些计划和当前计划在同一天，可以按实际出门场景保留或调整日期。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(sameDayPlans, id: \.id) { sameDayPlan in
                    NavigationLink {
                        PlanDetailView(plan: sameDayPlan)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sameDayPlan.date, format: .dateTime.hour().minute())
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(sameDayPlan.reminderEnabled ? "提醒" : "计划")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(width: 52)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(sameDayPlan.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(sameDayPlan.linkedOutfit?.title ?? sameDayPlan.outfitSummary)
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

    private var outfitSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "套用预设", subtitle: outfits.isEmpty ? "暂无预设" : "\(outfits.count) 套")

            if outfits.isEmpty {
                Text("先保存一套 OOTD 预设，再回来把它安排到这条计划。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(outfits, id: \.id) { outfit in
                            let isSelected = selectedOutfitID == outfit.persistentModelID

                            Button {
                                selectedOutfitID = isSelected ? nil : outfit.persistentModelID
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Text(outfit.title)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)

                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption.weight(.bold))
                                        }
                                    }

                                    Text(outfit.summaryText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(width: 190, alignment: .leading)
                                .padding(14)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .glassCard(
                                cornerRadius: HomeMetrics.secondaryRadius,
                                tint: isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.12)
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                if selectedOutfitID != nil {
                    Button {
                        selectedOutfitID = nil
                    } label: {
                        Label("移除预设", systemImage: "link.badge.minus")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    @ViewBuilder
    private var linkedOutfitSection: some View {
        if let outfit = selectedOutfit {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(title: "当前 OOTD", subtitle: outfit.title)

                Text(outfit.summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if outfit.isIncomplete {
                    Text("这套搭配存在缺失单品：\(outfit.missingSlotTitles.joined(separator: "、"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(outfit.orderedItems, id: \.id) { item in
                            WardrobeItemCard(item: item, emphasis: .carousel)
                                .frame(width: 184)
                        }
                    }
                    .padding(.vertical, 2)
                }

                NavigationLink {
                    OOTDDetailView(outfit: outfit)
                } label: {
                    Label("查看搭配详情", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(HomePressableButtonStyle())
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
            }
            .padding(18)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: "当前预设", subtitle: "未绑定")

                Text("这条计划暂时没有套用 OOTD 预设。保存后首页和计划列表会继续显示计划信息，但不会跳转到搭配详情。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "备注", subtitle: "可调整")
            TextField("例如：出门前记得拿外套", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "提醒设置", subtitle: "单次通知")

            Toggle(isOn: $reminderEnabled) {
                Text("开启提醒")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.switch)

            if reminderEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        #if os(iOS)
                        .datePickerStyle(.wheel)
                        #else
                        .datePickerStyle(.compact)
                        #endif
                        .frame(maxHeight: 110)
                        .padding(.horizontal, 8)
                        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))

                    if !reminderDateIsValid {
                        Label("提醒时间需要晚于当前时间", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                saveChanges()
            } label: {
                Label(isSaving ? "保存中…" : "保存计划修改", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.2))
            .disabled(isSaving || !canSaveChanges)
            .opacity(canSaveChanges ? 1 : 0.58)

            Button {
                reusePlanForNextTime()
            } label: {
                Label("复制到下一次", systemImage: "calendar.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.16))
            .disabled(isSaving)

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("删除计划", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(HomePressableButtonStyle())
            .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.12))
        }
    }

    private var deletionImpactSection: some View {
        DeletionImpactCard(summary: deletionImpact)
    }

    private func saveChanges() {
        guard !isSaving else { return }
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOccasion = occasion.trimmingCharacters(in: .whitespacesAndNewlines)
        let hadLinkedOutfit = plan.linkedOutfit != nil
        let selectedOutfit = selectedOutfit

        plan.title = trimmedTitle.isEmpty ? "未命名计划" : trimmedTitle
        plan.occasion = trimmedOccasion.isEmpty ? "穿搭安排" : trimmedOccasion
        plan.date = date
        plan.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.linkedOutfit = selectedOutfit
        if let selectedOutfit {
            plan.outfitSummary = selectedOutfit.summaryText
        } else if hadLinkedOutfit || plan.outfitSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            plan.outfitSummary = "未套用预设"
        }
        plan.reminderEnabled = reminderEnabled
        plan.reminderDate = reminderEnabled ? combinedReminderDate : nil
        plan.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            showPersistenceFailure(title: "计划保存失败", error: error)
            isSaving = false
            return
        }

        Task {
            let result: PlannerNotificationResult
            if reminderEnabled {
                result = await PlannerNotificationManager.scheduleNotification(for: plan)
            } else {
                await PlannerNotificationManager.removeNotification(for: plan)
                result = .disabled
            }

            await MainActor.run {
                if !result.isScheduled {
                    plan.reminderEnabled = false
                    plan.reminderDate = nil
                    plan.updatedAt = .now
                    reminderEnabled = false
                }
                do {
                    try modelContext.save()
                    feedback = .notificationResult(result)
                    isSaving = false
                } catch {
                    showPersistenceFailure(title: "计划保存失败", error: error)
                    isSaving = false
                }
            }
        }
    }

    private func reusePlanForNextTime() {
        guard !isSaving else { return }
        isSaving = true

        let targetDate = nextReuseDate
        let selectedOutfit = selectedOutfit
        let targetReminderDate = reminderEnabled ? combinedReminderDate(on: targetDate) : nil
        let keepsReminder = reminderEnabled && (targetReminderDate ?? .now) > .now
        let copiedPlan = OutfitPlan(
            date: targetDate,
            title: displayTitle,
            occasion: displayOccasion,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            outfitSummary: selectedOutfit?.summaryText ?? plan.outfitSummary,
            reminderEnabled: keepsReminder,
            reminderDate: keepsReminder ? targetReminderDate : nil,
            linkedOutfit: selectedOutfit
        )
        modelContext.insert(copiedPlan)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(copiedPlan)
            showPersistenceFailure(title: "计划复制失败", error: error)
            isSaving = false
            return
        }

        Task {
            var result: PlannerNotificationResult?
            if copiedPlan.reminderEnabled {
                result = await PlannerNotificationManager.scheduleNotification(for: copiedPlan)
            }

            await MainActor.run {
                if let result, !result.isScheduled {
                    copiedPlan.reminderEnabled = false
                    copiedPlan.reminderDate = nil
                    copiedPlan.updatedAt = .now
                }
                do {
                    try modelContext.save()
                    AppHaptics.success()
                    feedback = .planSaved(copiedPlan, notificationResult: result)
                    isSaving = false
                } catch {
                    showPersistenceFailure(title: "计划复制失败", error: error)
                    isSaving = false
                }
            }
        }
    }

    private func deletePlan() {
        Task {
            await PlannerNotificationManager.removeNotification(for: plan)
            await MainActor.run {
                modelContext.delete(plan)
                do {
                    try modelContext.save()
                    dismiss()
                } catch {
                    showPersistenceFailure(title: "计划删除失败", error: error)
                }
            }
        }
    }

    private func showPersistenceFailure(title: String, error: Error) {
        feedback = ActionFeedbackState(
            title: title,
            message: error.localizedDescription,
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    private var combinedReminderDate: Date {
        combinedReminderDate(on: date)
    }

    private func combinedReminderDate(on targetDate: Date) -> Date {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        return Calendar.current.date(from: DateComponents(
            year: day.year,
            month: day.month,
            day: day.day,
            hour: time.hour,
            minute: time.minute
        )) ?? targetDate
    }

    private var reminderDateIsValid: Bool {
        combinedReminderDate > .now
    }

    private var canSaveChanges: Bool {
        !reminderEnabled || reminderDateIsValid
    }

    private var deletionImpact: DeletionImpactSummary {
        DeletionImpactSummary.plan(
            planTitle: displayTitle,
            reminderEnabled: plan.reminderEnabled,
            hasLinkedOutfit: plan.linkedOutfit != nil
        )
    }

    private var selectedOutfit: OOTDOutfit? {
        guard let selectedOutfitID else { return nil }
        return outfits.first { $0.persistentModelID == selectedOutfitID }
    }

    private var sameDayPlans: [OutfitPlan] {
        plans
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.id != plan.id }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.date < rhs.date
            }
    }

    private var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "未命名计划" : trimmedTitle
    }

    private var displayOccasion: String {
        let trimmedOccasion = occasion.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedOccasion.isEmpty ? "穿搭安排" : trimmedOccasion
    }

    private var nextReuseDate: Date {
        let calendar = Calendar.current
        let sourceDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: .now)
        let baseDay = sourceDay < today ? today : sourceDay
        return calendar.date(byAdding: .day, value: 1, to: baseDay) ?? date
    }

    private var background: some View {
        AppAdaptiveBackground()
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func textField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
        }
    }
}

#Preview("Plan Detail") {
    NavigationStack {
        let items = Dictionary(uniqueKeysWithValues: WardrobeMockData.items.map { ($0.name, $0) })
        let outfitSeed = WardrobeMockData.outfits.first!
        let outfit = OOTDOutfit(
            title: outfitSeed.title,
            notes: outfitSeed.notes,
            isToday: outfitSeed.isToday,
            topItem: outfitSeed.topName.flatMap { items[$0] },
            bottomItem: outfitSeed.bottomName.flatMap { items[$0] },
            outerwearItem: outfitSeed.outerwearName.flatMap { items[$0] },
            shoesItem: outfitSeed.shoesName.flatMap { items[$0] },
            bagItem: outfitSeed.bagName.flatMap { items[$0] },
            accessoryItem: outfitSeed.accessoryName.flatMap { items[$0] }
        )
        let plan = OutfitPlan(
            date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
            title: "周二通勤",
            occasion: "办公室",
            notes: "开会前直接查看这套通勤搭配。",
            outfitSummary: outfit.summaryText,
            reminderEnabled: true,
            reminderDate: Calendar.current.date(bySettingHour: 8, minute: 20, second: 0, of: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now),
            linkedOutfit: outfit
        )
        PlanDetailView(plan: plan)
    }
}
