import SwiftData
import SwiftUI

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]

    @State private var title = "新的穿搭计划"
    @State private var occasion = "穿搭安排"
    @State private var notes = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var reminderEnabled = true
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: .now) ?? .now
    @State private var selectedOutfitID: PersistentIdentifier?
    @State private var isSaving = false
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""
    private let showsPreselectedHint: Bool
    private let onSaved: ((OutfitPlan, PlannerNotificationResult?) -> Void)?

    init(
        draft: PlanCreationDraft? = nil,
        initialSelectedOutfitID: PersistentIdentifier? = nil,
        suggestedTitle: String? = nil,
        onSaved: ((OutfitPlan, PlannerNotificationResult?) -> Void)? = nil
    ) {
        let defaultDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        let draftDate = draft?.date ?? defaultDate
        let defaultReminderTime = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: draftDate) ?? draftDate
        let selectedOutfitID = draft?.selectedOutfitID ?? initialSelectedOutfitID

        _selectedOutfitID = State(initialValue: selectedOutfitID)
        _title = State(initialValue: draft?.title ?? suggestedTitle ?? "新的穿搭计划")
        _occasion = State(initialValue: draft?.occasion ?? "穿搭安排")
        _notes = State(initialValue: draft?.notes ?? "")
        _date = State(initialValue: draftDate)
        _reminderEnabled = State(initialValue: draft?.reminderEnabled ?? true)
        _reminderTime = State(initialValue: draft?.reminderTime ?? defaultReminderTime)
        showsPreselectedHint = selectedOutfitID != nil
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("新建穿搭计划")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("选一个日期，再绑定一套已保存 OOTD，先完成本地计划闭环。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if showsPreselectedHint, let selectedOutfit {
                    preselectedOutfitBanner(outfit: selectedOutfit)
                }

                formSection
                outfitSelectionSection
                reminderSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 36)
        }
        .background(background)
        .navigationTitle("新建计划")
        .homeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中…" : "保存") {
                    savePlan()
                }
                .disabled(!canSave || isSaving)
            }
        }
        .alert("计划保存失败", isPresented: $showsSaveError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "计划信息", subtitle: "日期与备注")

            textField(title: "计划标题", text: $title, prompt: "例如：周三通勤")
            textField(title: "场景", text: $occasion, prompt: "例如：办公室 / 会面 / 周末")
            textField(title: "备注", text: $notes, prompt: "例如：下午开会前记得换上外套")

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
    }

    private var outfitSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "绑定 OOTD", subtitle: outfits.isEmpty ? "暂无搭配" : "\(outfits.count) 套")

            if outfits.isEmpty {
                Text("先去 OOTD 页面保存至少一套搭配，这里才能创建计划。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(outfits, id: \.id) { outfit in
                            let isSelected = selectedOutfitID == outfit.persistentModelID

                            Button {
                                selectedOutfitID = isSelected ? nil : outfit.persistentModelID
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(outfit.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
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
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "提醒", subtitle: "单次通知")

            Toggle(isOn: $reminderEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("开启提醒")
                        .font(.subheadline.weight(.semibold))
                    Text("会创建一条本地通知，提醒你查看当天 OOTD。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if reminderEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("提醒时间")
                        .font(.subheadline.weight(.semibold))

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
    }

    private func preselectedOutfitBanner(outfit: OOTDOutfit) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.82))

            VStack(alignment: .leading, spacing: 5) {
                Text("已自动预选搭配")
                    .font(.subheadline.weight(.semibold))
                Text("当前正在为“\(outfit.title)”创建计划，你可以直接选日期并保存。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.18))
    }

    private var selectedOutfit: OOTDOutfit? {
        guard let selectedOutfitID else { return nil }
        return outfits.first { $0.persistentModelID == selectedOutfitID }
    }

    private var canSave: Bool {
        selectedOutfit != nil && (!reminderEnabled || reminderDateIsValid)
    }

    private var reminderDateIsValid: Bool {
        combinedReminderDate > .now
    }

    private var combinedReminderDate: Date {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        return Calendar.current.date(from: DateComponents(
            year: day.year,
            month: day.month,
            day: day.day,
            hour: time.hour,
            minute: time.minute
        )) ?? date
    }

    private func savePlan() {
        guard let selectedOutfit, !isSaving else { return }
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOccasion = occasion.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = OutfitPlan(
            date: date,
            title: trimmedTitle.isEmpty ? "未命名计划" : trimmedTitle,
            occasion: trimmedOccasion.isEmpty ? "穿搭安排" : trimmedOccasion,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            outfitSummary: selectedOutfit.summaryText,
            reminderEnabled: reminderEnabled,
            reminderDate: reminderEnabled ? combinedReminderDate : nil,
            linkedOutfit: selectedOutfit
        )

        modelContext.insert(plan)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(plan)
            saveErrorMessage = error.localizedDescription
            showsSaveError = true
            isSaving = false
            return
        }

        Task {
            var notificationResult: PlannerNotificationResult?
            if reminderEnabled {
                notificationResult = await PlannerNotificationManager.scheduleNotification(for: plan)
            }
            await MainActor.run {
                if let notificationResult, !notificationResult.isScheduled {
                    plan.reminderEnabled = false
                    plan.reminderDate = nil
                    plan.updatedAt = .now
                }
                do {
                    try modelContext.save()
                    AppHaptics.success()
                    onSaved?(plan, notificationResult)
                    isSaving = false
                    dismiss()
                } catch {
                    saveErrorMessage = error.localizedDescription
                    showsSaveError = true
                    isSaving = false
                }
            }
        }
    }

    private var background: some View {
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
}

#Preview("Create Plan") {
    NavigationStack {
        CreatePlanView()
    }
    .modelContainer(WardrobePreviewContainer.shared)
}
