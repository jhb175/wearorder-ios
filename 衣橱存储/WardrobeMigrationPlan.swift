import Foundation
import SwiftData

enum WardrobeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WardrobeSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
