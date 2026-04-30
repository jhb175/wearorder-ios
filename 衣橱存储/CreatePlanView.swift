import SwiftData
import SwiftUI

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OOTDOutfit.createdAt, order: .reverse) private var outfits: [OOTDOutfit]
    @Query(sort: \OutfitPlan.date) private var plans: [OutfitPlan]

    @State private var selectedPlanKind: OutfitPlanKind = .daily
    @State private var title = "新的穿搭计划"
    @State private var occasion = "穿搭安排"
    @State private var locationName = ""
    @State private var weatherCityName = ""
    @State private var notes = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var reminderEnabled = true
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: .now) ?? .now
    @State private var selectedOutfitID: PersistentIdentifier?
    @State private var presetSearchText = ""
    @State private var visiblePresetLimit = 8
    @State private var isSaving = false
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""
    private let showsPreselectedHint: Bool
    private let onSaved: ((OutfitPlan, PlannerNotificationResult?) -> Void)?
    private let presetPageSize = 8

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
        _selectedPlanKind = State(initialValue: draft?.planKind ?? .daily)
        _title = State(initialValue: draft?.title ?? suggestedTitle ?? "新的穿搭计划")
        _occasion = State(initialValue: draft?.occasion ?? "穿搭安排")
        _locationName = State(initialValue: draft?.locationName ?? "")
        _weatherCityName = State(initialValue: draft?.weatherCityName ?? "")
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
                    Text(showsPreselectedHint ? "安排 OOTD 到日期" : "新建穿搭计划")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(showsPreselectedHint ? "这套 OOTD 会作为预设保存，你只需要选日期、场景和提醒。" : "选一个日期，再套用一套 OOTD 预设。同一套预设可以重复安排到不同日期。")
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
        .navigationTitle(showsPreselectedHint ? "安排日期" : "新建计划")
        .homeInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中…" : (showsPreselectedHint ? "安排" : "保存")) {
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
        .onChange(of: presetSearchText) { _, _ in
            visiblePresetLimit = presetPageSize
        }
        .onChange(of: outfits) { _, _ in
            visiblePresetLimit = min(max(presetPageSize, visiblePresetLimit), max(presetPageSize, filteredOutfits.count))
        }
        .onChange(of: selectedPlanKind) { oldKind, newKind in
            refreshDefaultsWhenKindChanges(from: oldKind, to: newKind)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "计划信息", subtitle: "日期与备注")

            planKindPicker
            textField(title: "计划标题", text: $title, prompt: "例如：周三通勤")
            textField(title: "场景", text: $occasion, prompt: "例如：办公室 / 会面 / 周末")
            textField(title: selectedPlanKind.locationFieldTitle, text: $locationName, prompt: selectedPlanKind.locationFieldPrompt)
            textField(title: "天气城市", text: $weatherCityName, prompt: "例如：上海 / Tokyo / New York")
            Text(selectedPlanKind.locationHelperText)
                .font(.caption)
                .foregroundStyle(.secondary)
            textField(title: "备注", text: $notes, prompt: "例如：下午开会前记得换上外套")

            VStack(alignment: .leading, spacing: 8) {
                Text("计划日期")
                    .font(.subheadline.weight(.semibold))

                DatePicker("计划日期", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .padding(12)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))

                if !plansOnSelectedDate.isEmpty {
                    sameDayPlanNotice
                }
            }
        }
    }

    private var sameDayPlanNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.82))

            VStack(alignment: .leading, spacing: 5) {
                Text("这一天已有 \(plansOnSelectedDate.count) 条计划")
                    .font(.caption.weight(.semibold))
                Text("保存后会新增一条安排，不会覆盖原计划。之后可在计划详情里调整或删除。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.orange.opacity(0.10))
    }

    private var planKindPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("计划类型")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                ForEach(OutfitPlanKind.allCases) { kind in
                    Button {
                        selectedPlanKind = kind
                        AppHaptics.selection()
                    } label: {
                        Label(kind.title, systemImage: kind.symbolName)
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(HomePressableButtonStyle())
                    .homeCardSurface(
                        weight: selectedPlanKind == kind ? .secondary : .tertiary,
                        cornerRadius: HomeMetrics.pillRadius
                    )
                }
            }

            Text(selectedPlanKind.helperText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var outfitSelectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "选择 OOTD 预设", subtitle: presetSelectionSubtitle)

            if outfits.isEmpty {
                Text("先去 OOTD 的预设库保存至少一套常用组合，这里才能直接排期。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
            } else {
                presetSearchField

                if let selectedOutfit {
                    selectedPresetCard(outfit: selectedOutfit)
                }

                if filteredOutfits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("没有匹配的预设")
                            .font(.headline)
                        Text("换个关键词，或清空搜索后查看全部 OOTD 预设。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            presetSearchText = ""
                        } label: {
                            Label("清空搜索", systemImage: "xmark.circle")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(HomePressableButtonStyle())
                        .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                    }
                    .padding(18)
                    .glassCard(cornerRadius: HomeMetrics.secondaryRadius)
                } else {
                    VStack(spacing: 10) {
                        ForEach(displayedOutfits, id: \.id) { outfit in
                            selectablePresetCard(outfit: outfit)
                        }

                        if hasMoreOutfits {
                            Button {
                                visiblePresetLimit += presetPageSize
                                AppHaptics.selection()
                            } label: {
                                HStack {
                                    Text("继续加载预设")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(displayedOutfits.count)/\(filteredOutfits.count)")
                                        .font(.caption.monospacedDigit().weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(HomePressableButtonStyle())
                            .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.secondaryRadius)
                        }
                    }
                }
            }
        }
    }

    private var presetSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("搜索 OOTD、场景或单品", text: $presetSearchText)
                .textFieldStyle(.plain)
                .font(.subheadline)

            if !presetSearchText.isEmpty {
                Button {
                    presetSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空预设搜索")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.14))
    }

    private func selectedPresetCard(outfit: OOTDOutfit) -> some View {
        HStack(alignment: .center, spacing: 12) {
            presetThumbnailStrip(for: outfit, maxItems: 3)
                .frame(width: 120, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Label("当前选择", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                Text(outfit.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(outfit.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.green.opacity(0.12))
    }

    private func selectablePresetCard(outfit: OOTDOutfit) -> some View {
        let isSelected = selectedOutfitID == outfit.persistentModelID

        return Button {
            selectedOutfitID = isSelected ? nil : outfit.persistentModelID
            AppHaptics.selection()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                presetThumbnailStrip(for: outfit, maxItems: 3)
                    .frame(width: 112, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(outfit.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if outfit.isToday {
                            Text("今日")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .homeCardSurface(weight: .tertiary, cornerRadius: HomeMetrics.pillRadius)
                        }
                    }

                    Text(outfit.notes.isEmpty ? outfit.summaryText : outfit.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(outfit.summaryText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? .green : .secondary)
            }
            .padding(14)
        }
        .buttonStyle(HomePressableButtonStyle())
        .glassCard(
            cornerRadius: HomeMetrics.secondaryRadius,
            tint: isSelected ? Color.green.opacity(0.14) : Color.white.opacity(0.12)
        )
    }

    private func presetThumbnailStrip(for outfit: OOTDOutfit, maxItems: Int) -> some View {
        HStack(spacing: -12) {
            ForEach(Array(outfit.orderedItems.prefix(maxItems)), id: \.id) { item in
                WardrobeItemImageView(item: item, cornerRadius: 14, symbolFont: .caption.weight(.semibold))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.72), lineWidth: 1)
                    }
            }

            if outfit.orderedItems.isEmpty {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .overlay {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .aspectRatio(1, contentMode: .fit)
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
                Text("已自动套用预设")
                    .font(.subheadline.weight(.semibold))
                Text("当前正在把“\(outfit.title)”安排到日期里，可重复使用，不会影响原 OOTD。")
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

    private var filteredOutfits: [OOTDOutfit] {
        let query = presetSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return outfits }

        return outfits.filter { outfit in
            let itemFields = outfit.orderedItems.flatMap { item in
                item.searchableFields + item.styleTags
            }
            let searchableText = ([outfit.title, outfit.notes, outfit.summaryText] + itemFields + outfit.presetTags)
                .joined(separator: " ")
            return searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    private var plansOnSelectedDate: [OutfitPlan] {
        plans.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var displayedOutfits: [OOTDOutfit] {
        Array(filteredOutfits.prefix(visiblePresetLimit))
    }

    private var hasMoreOutfits: Bool {
        displayedOutfits.count < filteredOutfits.count
    }

    private var presetSelectionSubtitle: String {
        guard !outfits.isEmpty else { return "暂无预设" }
        if filteredOutfits.count == outfits.count {
            return "\(outfits.count) 套"
        }
        return "\(filteredOutfits.count) / \(outfits.count) 套"
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
            planKind: selectedPlanKind,
            date: date,
            title: trimmedTitle.isEmpty ? "未命名计划" : trimmedTitle,
            occasion: trimmedOccasion.isEmpty ? "穿搭安排" : trimmedOccasion,
            locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            weatherCityName: weatherCityName.trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func refreshDefaultsWhenKindChanges(from oldKind: OutfitPlanKind, to newKind: OutfitPlanKind) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOccasion = occasion.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty || trimmedTitle == oldKind.defaultTitle || trimmedTitle == "新的穿搭计划" {
            title = newKind.defaultTitle
        }

        if trimmedOccasion.isEmpty || trimmedOccasion == oldKind.defaultOccasion || trimmedOccasion == "穿搭安排" {
            occasion = newKind.defaultOccasion
        }
    }

    private var background: some View {
        AppAdaptiveBackground()
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
