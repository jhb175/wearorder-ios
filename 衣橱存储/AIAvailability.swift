import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Three-state runtime gate for the AI Stylist module.
///
/// We do not bump the app's deployment target to iOS 26.0; instead the
/// AI module is conditionally compiled and runtime-gated, so users on
/// older OS versions and devices keep using the rest of the app.
enum AIAvailability {

    enum State: Equatable {
        /// Apple Intelligence is on, the on-device model is ready.
        case available

        /// iOS 26+ but the system reports the model isn't ready —
        /// device ineligible, Apple Intelligence off, model still
        /// downloading, etc. The string is user-presentable.
        case unavailable(reason: String)

        /// Below iOS 26.0; the framework is not even importable.
        case needsNewerOS
    }

    /// Current runtime availability. Cheap to call — internally just a
    /// version check + framework state read.
    static var current: State {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return checkSystemLanguageModel()
        } else {
            return .needsNewerOS
        }
        #else
        return .needsNewerOS
        #endif
    }

    /// Whether the AI entry point should be exposed in UI.
    static var isAvailable: Bool {
        if case .available = current { return true }
        return false
    }

    static var disabledMessage: String {
        switch current {
        case .available:
            return ""
        case .unavailable(let reason):
            return reason
        case .needsNewerOS:
            return "AI 搭配师需要 iOS 26 及以上版本。"
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func checkSystemLanguageModel() -> State {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: localized(for: reason))
        @unknown default:
            return .unavailable(reason: "Apple Intelligence 当前不可用。")
        }
    }

    @available(iOS 26.0, *)
    private static func localized(
        for reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        // We use string matching because case names can change between
        // SDK versions and we don't want a non-exhaustive switch crash.
        let raw = String(describing: reason).lowercased()
        if raw.contains("ineligible") || raw.contains("notsupported") {
            return "当前设备不支持 Apple Intelligence。"
        }
        if raw.contains("notenabled") || raw.contains("disabled") {
            return "请在系统设置中开启 Apple Intelligence。"
        }
        if raw.contains("notready") || raw.contains("loading") || raw.contains("downloading") {
            return "AI 模型正在准备中，请稍后再试。"
        }
        return "Apple Intelligence 当前不可用：\(reason)"
    }
    #endif
}
