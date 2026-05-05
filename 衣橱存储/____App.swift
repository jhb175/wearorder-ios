import SwiftUI
import SwiftData

@main
struct YiChuCunChuApp: App {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.chinese.rawValue

    init() {
        MetricKitObserver.shared.start()
    }

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
    static let cloudKitFallbackFlagKey = "wearorder.cloudkit.localFallbackActive"

    static let schema = Schema(versionedSchema: WardrobeSchemaV1.self)

    static let shared: ModelContainer = {
        let configuration = makeConfiguration()

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: WardrobeMigrationPlan.self,
                configurations: [configuration]
            )
            UserDefaults.standard.set(false, forKey: cloudKitFallbackFlagKey)
            return container
        } catch {
            guard shouldUseCloudKit else {
                fatalError("Failed to create local SwiftData container: \(error)")
            }

            do {
                let fallbackContainer = try ModelContainer(
                    for: schema,
                    migrationPlan: WardrobeMigrationPlan.self,
                    configurations: [ModelConfiguration(schema: schema)]
                )
                UserDefaults.standard.set(true, forKey: cloudKitFallbackFlagKey)
                debugPrint("CloudKit SwiftData container unavailable; using local fallback store. \(error)")
                return fallbackContainer
            } catch {
                fatalError("Failed to create local SwiftData fallback container: \(error)")
            }
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
