import Foundation
import UserNotifications

enum PlannerNotificationResult: Equatable {
    case scheduled
    case disabled
    case missingDate
    case pastDate
    case permissionDenied
    case failed(String)

    var isScheduled: Bool {
        self == .scheduled
    }

    var feedbackTitle: String {
        switch self {
        case .scheduled:
            "提醒已保存"
        case .disabled:
            "已关闭提醒"
        case .missingDate, .pastDate:
            "计划已保存，提醒未创建"
        case .permissionDenied:
            "计划已保存，需要开启通知权限"
        case .failed:
            "计划已保存，提醒创建失败"
        }
    }

    var feedbackMessage: String {
        switch self {
        case .scheduled:
            "到点后会通过本地通知提醒你查看 OOTD。"
        case .disabled:
            "这条计划不会触发本地通知。"
        case .missingDate:
            "没有找到有效的提醒时间，已自动关闭这条计划的提醒。"
        case .pastDate:
            "提醒时间已经过去，已自动关闭这条计划的提醒。"
        case .permissionDenied:
            "请在系统设置里允许通知，再回来重新开启提醒。"
        case .failed(let reason):
            "系统没有接受这条通知：\(reason)"
        }
    }

    var feedbackSystemImage: String {
        switch self {
        case .scheduled:
            "bell.badge.fill"
        case .disabled:
            "bell.slash"
        case .missingDate, .pastDate, .permissionDenied, .failed:
            "exclamationmark.triangle.fill"
        }
    }
}

enum PlannerNotificationManager {
    @discardableResult
    static func scheduleNotification(for plan: OutfitPlan) async -> PlannerNotificationResult {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: plan)])

        guard plan.reminderEnabled else { return .disabled }
        guard let reminderDate = plan.reminderDate else { return .missingDate }
        guard reminderDate > .now else { return .pastDate }

        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else { return .permissionDenied }
            } catch {
                return .failed(error.localizedDescription)
            }
        case .denied:
            return .permissionDenied
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            return .permissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = "今天的穿搭已准备好"
        content.body = "\(plan.title) · 记得查看今天的 OOTD"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: plan),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            return .scheduled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func removeNotification(for plan: OutfitPlan) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: plan)])
    }

    static func identifier(for plan: OutfitPlan) -> String {
        "planner-\(plan.id.uuidString)"
    }
}
