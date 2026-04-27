import Foundation

enum WardrobeNotificationSynchronizer {
    @MainActor
    static func synchronizeImportedNotifications(_ plans: [OutfitPlan]) async -> Int {
        var scheduledCount = 0

        for plan in plans {
            let result = await PlannerNotificationManager.scheduleNotification(for: plan)
            if result.isScheduled {
                scheduledCount += 1
            } else if result != .disabled {
                plan.reminderEnabled = false
            }
        }

        return scheduledCount
    }
}
