import SwiftUI
import SwiftData

@main
struct YiChuCunChuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WardrobeItem.self, OutfitPlan.self, OOTDOutfit.self])
    }
}
