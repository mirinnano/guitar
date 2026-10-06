import XCTest
import GuitarToolsCore
@testable import GuitarToolsMacApp

@MainActor
final class RecentChartsStoreTests: XCTestCase {
    func testRecentLinksPersistDeduplicateAndStayBounded() throws {
        let suite = "recent-charts-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecentChartsStore(defaults: defaults)
        for index in 0..<20 {
            store.record(result(index))
        }
        store.record(result(10))
        XCTAssertEqual(store.entries.count, RecentChartsStore.limit)
        XCTAssertEqual(store.entries.first, result(10))
        XCTAssertEqual(store.entries.filter { $0.id == result(10).id }.count, 1)
        XCTAssertEqual(RecentChartsStore(defaults: defaults).entries, store.entries)
        store.remove(result(10))
        XCTAssertFalse(RecentChartsStore(defaults: defaults).entries.contains(result(10)))
        defaults.set(Data("broken".utf8), forKey: RecentChartsStore.storageKey)
        XCTAssertTrue(RecentChartsStore(defaults: defaults).entries.isEmpty)
    }

    func testOnlySuccessfulStillSelectedChartLoadsEnterHistory() async throws {
        let suite = "recent-chart-load-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecentChartsStore(defaults: defaults)
        let client = RecentChartClient()
        let model = ChordWikiViewerModel(client: client, recentStore: store)
        model.open(result(1))
        try await wait { await client.hasRequest }
        model.close()
        await client.finish(success: true)
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertNil(model.chart)
        XCTAssertTrue(store.entries.isEmpty)

        model.open(result(2))
        try await wait { await client.hasRequest }
        await client.finish(success: false)
        try await wait { !model.isLoading }
        XCTAssertTrue(store.entries.isEmpty)

        model.open(result(3))
        try await wait { await client.hasRequest }
        await client.finish(success: true)
        try await wait { model.chart != nil }
        XCTAssertEqual(model.recentCharts, [result(3)], "Keep the provider lookup title, not the title inside the chart")
        let restored = ChordWikiViewerModel(client: client, recentStore: RecentChartsStore(defaults: defaults))
        XCTAssertEqual(restored.recentCharts, model.recentCharts)
        XCTAssertNil(restored.chart, "History must not automatically load a chart or start playback")
        XCTAssertFalse(restored.isPlaying)
    }

    private func result(_ index: Int) -> ChordWikiSearchResult {
        ChordWikiSearchResult(title: "Song \(index)", url: URL(string: "https://ja.chordwiki.org/wiki/Song\(index)")!)
    }

    private func wait(_ predicate: () async -> Bool) async throws {
        for _ in 0..<100 {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for chart loading")
    }
}

private actor RecentChartClient: ChordWikiClientProtocol {
    private var request: CheckedContinuation<ChordChart, Error>?
    var hasRequest: Bool { request != nil }
    func search(query: String) async throws -> [ChordWikiSearchResult] { [] }
    func loadChart(_ result: ChordWikiSearchResult) async throws -> ChordChart {
        try await withCheckedThrowingContinuation { request = $0 }
    }
    func finish(success: Bool) {
        let continuation = request
        request = nil
        if success {
            continuation?.resume(returning: ChordChart(sourceTitle: "Source", title: "Song", lines: []))
        } else {
            continuation?.resume(throwing: URLError(.cannotLoadFromNetwork))
        }
    }
}
