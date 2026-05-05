import Foundation
import SwiftData

enum WardrobeSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            WardrobeItem.self,
            OutfitPlan.self,
            OOTDOutfit.self
        ]
    }
}
