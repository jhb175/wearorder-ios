import Foundation
import MetricKit

struct DiagnosticsStorage: Sendable {
    enum Kind: String, Sendable {
        case metric
        case diagnostic
    }

    let rootDirectoryURL: URL
    let maxFileCount: Int
    let dateProvider: @Sendable () -> Date

    static func applicationSupport(maxFileCount: Int = 30) -> DiagnosticsStorage {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return DiagnosticsStorage(
            rootDirectoryURL: support.appendingPathComponent("WearOrderDiagnostics", isDirectory: true),
            maxFileCount: maxFileCount,
            dateProvider: { Date() }
        )
    }

    func persist(_ data: Data, kind: Kind) throws -> URL {
        try ensureDirectoryExists()
        let timestamp = Self.timestampFormatter.string(from: dateProvider())
        let filename = "\(kind.rawValue)-\(timestamp).json"
        let url = rootDirectoryURL.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: [.atomic])
        try pruneToCap()
        return url
    }

    func storedFiles() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: rootDirectoryURL.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: rootDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    }

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
    }

    private func pruneToCap() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: rootDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        guard files.count > maxFileCount else { return }

        let sortedDescending = files.sorted { lhs, rhs in
            modificationDate(of: lhs) > modificationDate(of: rhs)
        }

        for stale in sortedDescending.dropFirst(maxFileCount) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        return formatter
    }()
}

final class MetricKitObserver: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = MetricKitObserver()

    private let storage: DiagnosticsStorage

    init(storage: DiagnosticsStorage = .applicationSupport()) {
        self.storage = storage
        super.init()
    }

    func start() {
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            try? storage.persist(payload.jsonRepresentation(), kind: .metric)
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            try? storage.persist(payload.jsonRepresentation(), kind: .diagnostic)
        }
    }
}
