import SwiftUI

struct ActionFeedbackState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil
}

extension ActionFeedbackState {
    static func planSaved(
        _ plan: OutfitPlan,
        notificationResult: PlannerNotificationResult?
    ) -> ActionFeedbackState {
        guard let notificationResult, notificationResult != .scheduled else {
            return ActionFeedbackState(
                title: "已保存计划",
                message: "“\(plan.title)”已加入近期穿搭安排。"
            )
        }

        let settingsAction = notificationSettingsAction(for: notificationResult)
        return ActionFeedbackState(
            title: notificationResult.feedbackTitle,
            message: "“\(plan.title)”已保存。\(notificationResult.feedbackMessage)",
            systemImage: notificationResult.feedbackSystemImage,
            actionTitle: settingsAction?.title,
            onAction: settingsAction?.handler
        )
    }

    static func notificationResult(_ result: PlannerNotificationResult) -> ActionFeedbackState {
        let settingsAction = notificationSettingsAction(for: result)
        return ActionFeedbackState(
            title: result.feedbackTitle,
            message: result.feedbackMessage,
            systemImage: result.feedbackSystemImage,
            actionTitle: settingsAction?.title,
            onAction: settingsAction?.handler
        )
    }

    private static func notificationSettingsAction(
        for result: PlannerNotificationResult
    ) -> (title: String, handler: () -> Void)? {
        guard result == .permissionDenied else { return nil }
        return ("去设置", { AppSettings.open() })
    }
}

struct ActionFeedbackBanner: View {
    let title: String
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var actionTitle: String? = nil
    var onAction: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    var autoDismissDelay: Duration? = .seconds(3)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.85))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let actionTitle, let onAction {
                    Button(actionTitle) {
                        onAction()
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 8)

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: HomeMetrics.secondaryRadius, tint: Color.white.opacity(0.22))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 10)
        .task(id: title + message) {
            guard let autoDismissDelay, actionTitle == nil, let onDismiss else { return }
            do {
                try await Task.sleep(for: autoDismissDelay)
                await MainActor.run {
                    onDismiss()
                }
            } catch {
            }
        }
    }
}
