import SwiftData
import SwiftUI

struct EditClothingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: WardrobeItem
    var onSaved: ((WardrobeItem) -> Void)? = nil

    @State private var draft: ClothingDraft
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""

    init(item: WardrobeItem, onSaved: ((WardrobeItem) -> Void)? = nil) {
        self.item = item
        self.onSaved = onSaved
        _draft = State(initialValue: ClothingDraft(item: item))
    }

    var body: some View {
        NavigationStack {
            ClothingEditorForm(
                draft: $draft,
                showsSaveSection: false,
                saveButtonTitle: "保存修改",
                onSave: saveChanges
            )
            .navigationTitle("编辑衣物")
            .homeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(!draft.isValid)
                }
            }
            .alert("衣物保存失败", isPresented: $showsSaveError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private func saveChanges() {
        item.name = draft.trimmedName
        item.category = draft.category
        item.colorName = draft.colorName
        item.season = draft.season
        item.imageSymbol = draft.imageSymbol
        item.imageData = draft.imageData
        item.thumbnailData = draft.thumbnailData
        item.styleTagsText = draft.styleTagsText
        item.notes = draft.notes
        item.brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        item.size = draft.size.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.size.trimmingCharacters(in: .whitespacesAndNewlines)
        item.purchasePrice = draft.normalizedPurchasePrice
        item.purchaseDate = draft.hasPurchaseDate ? draft.purchaseDate : nil
        item.purchaseChannel = draft.purchaseChannel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.purchaseChannel.trimmingCharacters(in: .whitespacesAndNewlines)
        item.careNotes = draft.careNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.careNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        item.updatedAt = .now
        do {
            try modelContext.save()
            AppHaptics.success()
            onSaved?(item)
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showsSaveError = true
        }
    }
}

#Preview("Edit Clothing") {
    NavigationStack {
        EditClothingView(item: WardrobeMockData.items[0])
    }
    .modelContainer(WardrobePreviewContainer.shared)
}
