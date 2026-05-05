import XCTest
@testable import 衣橱存储

final class DiagnosticsStorageTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiagnosticsStorageTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
        rootURL = nil
        try super.tearDownWithError()
    }

    func testPersistCreatesFileWithExpectedContents() throws {
        let storage = makeStorage()
        let payload = Data("{\"sample\":true}".utf8)

        let url = try storage.persist(payload, kind: .metric)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), payload)
    }

    func testPersistedFilenamesUseKindPrefix() throws {
        let storage = makeStorage()

        let metricURL = try storage.persist(Data([0x01]), kind: .metric)
        let diagnosticURL = try storage.persist(Data([0x02]), kind: .diagnostic)

        XCTAssertTrue(metricURL.lastPathComponent.hasPrefix("metric-"))
        XCTAssertTrue(diagnosticURL.lastPathComponent.hasPrefix("diagnostic-"))
        XCTAssertTrue(metricURL.lastPathComponent.hasSuffix(".json"))
        XCTAssertTrue(diagnosticURL.lastPathComponent.hasSuffix(".json"))
    }

    func testPersistPrunesOldestWhenCapExceeded() throws {
        let cap = 3
        var clockOffset: TimeInterval = 0
        let storage = DiagnosticsStorage(
            rootDirectoryURL: rootURL,
            maxFileCount: cap,
            dateProvider: {
                let now = Date(timeIntervalSince1970: 1_500_000_000 + clockOffset)
                return now
            }
        )

        var writtenURLs: [URL] = []
        for index in 0..<5 {
            clockOffset = TimeInterval(index)
            let url = try storage.persist(Data([UInt8(index)]), kind: .metric)
            writtenURLs.append(url)
            // Touch the file's mtime so the prune step can actually order them.
            // ISO8601-second-resolution timestamps mean two same-second writes
            // can otherwise collapse into a single filename.
            try setModificationDate(at: url, to: Date(timeIntervalSince1970: 1_500_000_000 + clockOffset))
        }

        let remaining = try storage.storedFiles()
        XCTAssertEqual(remaining.count, cap)

        let remainingNames = Set(remaining.map(\.lastPathComponent))
        // Two oldest should be gone.
        XCTAssertFalse(remainingNames.contains(writtenURLs[0].lastPathComponent))
        XCTAssertFalse(remainingNames.contains(writtenURLs[1].lastPathComponent))
        // Three newest should survive.
        XCTAssertTrue(remainingNames.contains(writtenURLs[2].lastPathComponent))
        XCTAssertTrue(remainingNames.contains(writtenURLs[3].lastPathComponent))
        XCTAssertTrue(remainingNames.contains(writtenURLs[4].lastPathComponent))
    }

    func testStoredFilesReturnsEmptyWhenDirectoryAbsent() throws {
        let storage = makeStorage()

        let files = try storage.storedFiles()

        XCTAssertTrue(files.isEmpty)
    }

    func testStoredFilesListsAllPersistedAcrossKinds() throws {
        let storage = makeStorage()

        var clockOffset: TimeInterval = 0
        let baseDate = Date(timeIntervalSince1970: 1_500_000_000)
        let writeOne: (DiagnosticsStorage.Kind) throws -> URL = { kind in
            let storage = DiagnosticsStorage(
                rootDirectoryURL: self.rootURL,
                maxFileCount: 30,
                dateProvider: { baseDate.addingTimeInterval(clockOffset) }
            )
            clockOffset += 1
            return try storage.persist(Data([0x55]), kind: kind)
        }
        _ = try writeOne(.metric)
        _ = try writeOne(.diagnostic)
        _ = try writeOne(.metric)

        _ = storage // silence unused warning if any
        let files = try DiagnosticsStorage(
            rootDirectoryURL: rootURL,
            maxFileCount: 30,
            dateProvider: { baseDate }
        ).storedFiles()

        XCTAssertEqual(files.count, 3)
    }

    // MARK: - Helpers

    private func makeStorage(maxFileCount: Int = 30) -> DiagnosticsStorage {
        DiagnosticsStorage(
            rootDirectoryURL: rootURL,
            maxFileCount: maxFileCount,
            dateProvider: { Date() }
        )
    }

    private func setModificationDate(at url: URL, to date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
