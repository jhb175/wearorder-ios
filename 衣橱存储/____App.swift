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
        .modelContainer(WardrobePersistentStore.shared)
    }
}

enum WardrobePersistentStore {
    static let cloudKitContainerIdentifier = "iCloud.com.ramsey.wearorder"
    static let disableCloudKitEnvironmentKey = "WEARORDER_DISABLE_CLOUDKIT"

    static let schema = Schema([
        WardrobeItem.self,
        OutfitPlan.self,
        OOTDOutfit.self
    ])

    static let shared: ModelContainer = {
        let configuration = makeConfiguration()

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create CloudKit-backed SwiftData container: \(error)")
        }
    }()

    static func makeConfiguration() -> ModelConfiguration {
        guard shouldUseCloudKit else {
            return ModelConfiguration(schema: schema)
        }

        return ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )
    }

    static var shouldUseCloudKit: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment[disableCloudKitEnvironmentKey] == "1" {
            return false
        }

        if environment["XCTestConfigurationFilePath"] != nil ||
            environment["XCTestBundlePath"] != nil {
            return false
        }

        return true
    }
}
