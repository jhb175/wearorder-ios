import SwiftUI
import SwiftData

@main
struct YiChuCunChuApp: App {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.chinese.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, AppLanguage.value(for: appLanguageRawValue).locale)
        }
        .modelContainer(for: [WardrobeItem.self, OutfitPlan.self, OOTDOutfit.self])
    }
}
