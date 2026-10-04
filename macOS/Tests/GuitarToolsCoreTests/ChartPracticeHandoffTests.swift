import XCTest
import GuitarToolsCore
@testable import GuitarToolsMacApp

@MainActor
final class ChartPracticeHandoffTests: XCTestCase {
    private let defaultsName = "ChartPracticeHandoffTests.\(UUID().uuidString)"
    private lazy var defaults = UserDefaults(suiteName: defaultsName)!
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    func testLoadedChartHandoffPreservesSelectedTempoAndPositionWithoutNetwork() async {
        let client = SuspendedPracticeClient()
        let model = makeModel(client: client)
        let chart = makeChart("Loaded song", bpm: 150)
        let request = ChartPracticeRequest(chart: chart, beat: 3.5, bpm: 84)

        model.loadPractice(request)

        XCTAssertEqual(model.chart, chart)
        XCTAssertEqual(model.bpm, 84, "Use the selected tempo, not chart metadata")
        XCTAssertEqual(model.currentBeat, 3.5, accuracy: 0.0001)
        XCTAssertEqual(model.currentSeconds, 2.5, accuracy: 0.0001)
        XCTAssertFalse(model.isPlaying)
        XCTAssertFalse(model.isLoadingChart)
        XCTAssertTrue(model.attempts.isEmpty)
        XCTAssertNil(model.lastAttempt)
        XCTAssertNil(model.pendingExpected)
        let calls = await client.callCount()
        XCTAssertEqual(calls, 0)
    }

    func testPositionIsClampedToTheLoadedTimeline() {
        let model = makeModel(client: SuspendedPracticeClient())
        let chart = makeChart("Song")
        let totalBeats = ChordTimelineBuilder.build(chart: chart).totalBeats
        XCTAssertGreaterThan(totalBeats, 0)

        for (requested, expected) in [
            (-5.0, 0.0), (totalBeats + 20, totalBeats),
            (Double.infinity, totalBeats), (-Double.infinity, 0), (Double.nan, 0)
        ] {
            model.loadPractice(ChartPracticeRequest(chart: chart, beat: requested, bpm: 91))
            XCTAssertEqual(model.currentBeat, expected, accuracy: 0.0001)
            XCTAssertEqual(model.bpm, 91)
        }
    }

    func testRequestIdentityDoesNotReapplyPositionOnViewUpdates() {
        let model = makeModel(client: SuspendedPracticeClient())
        let chart = makeChart("Song")
        let request = ChartPracticeRequest(chart: chart, beat: 2, bpm: 120)
        model.loadPractice(request)
        model.seek(to: 0.25)
        model.bpm = 100

        model.loadPractice(request)

        XCTAssertEqual(model.currentSeconds, 0.25)
        XCTAssertEqual(model.bpm, 100)
        let freshRequest = ChartPracticeRequest(chart: chart, beat: 2, bpm: 120)
        XCTAssertNotEqual(request.id, freshRequest.id)
        model.loadPractice(freshRequest)
        XCTAssertEqual(model.currentBeat, 2, accuracy: 0.0001)
        XCTAssertEqual(model.bpm, 120)
    }

    func testEmptyChartAndInvalidTempoAreSafe() {
        let model = makeModel(client: SuspendedPracticeClient())
        let empty = ChordChart(sourceTitle: "Empty", title: "Empty", lines: [])
        model.loadPractice(ChartPracticeRequest(chart: empty, beat: 99, bpm: 0))
        XCTAssertEqual(model.currentSeconds, 0)
        XCTAssertEqual(model.durationSeconds, 0)
        XCTAssertGreaterThan(model.bpm, 0)
    }

    func testHandoffInvalidatesAnInFlightChartLoad() async throws {
        let client = SuspendedPracticeClient()
        let model = makeModel(client: client)
        model.open(ChordWikiSearchResult(
            title: "Old", url: URL(string: "https://ja.chordwiki.org/wiki/Old")!
        ))
        try await waitUntil { await client.hasChartRequest() }
        XCTAssertTrue(model.isLoadingChart)

        let handedOff = makeChart("Handed off")
        model.loadPractice(ChartPracticeRequest(chart: handedOff, beat: 1, bpm: 73))
        await client.finishChart(makeChart("Late network response"))
        // Allow the resumed main-actor task to finish its stale-request guard.
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(model.chart, handedOff)
        XCTAssertEqual(model.currentBeat, 1, accuracy: 0.0001)
        XCTAssertEqual(model.bpm, 73)
        XCTAssertFalse(model.isLoadingChart)
    }

    func testHandoffInvalidatesAnInFlightSearch() async throws {
        let client = SuspendedPracticeClient()
        let model = makeModel(client: client)
        model.query = "Old"
        model.search()
        try await waitUntil { await client.hasSearchRequest() }

        let handedOff = makeChart("Handed off")
        model.loadPractice(ChartPracticeRequest(chart: handedOff, beat: 2, bpm: 88))
        await client.finishSearch([ChordWikiSearchResult(
            title: "Late search", url: URL(string: "https://ja.chordwiki.org/wiki/Late")!
        )])
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(model.chart, handedOff)
        XCTAssertTrue(model.searchResults.isEmpty)
        XCTAssertFalse(model.isSearching)
        XCTAssertNil(model.errorMessage)
    }

    private func makeModel(client: any ChordWikiClientProtocol) -> ChordFollowPracticeModel {
        let suite = defaultsName
        let temporaryDirectory = directory
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let clock = FixedPracticeClock()
        return ChordFollowPracticeModel(
            audio: AudioInputModel(clock: clock),
            preferencesStore: AppPreferencesStore(defaults: defaults),
            clock: clock,
            sessionStore: PracticeSessionStore(directoryURL: directory),
            client: client
        )
    }

    private func makeChart(_ title: String, bpm: Int = 120) -> ChordChart {
        ChordChart(sourceTitle: title, title: title, bpm: bpm, lines: [
            ChartLine(segments: [
                ChartSegment(chord: "C", text: "one"),
                ChartSegment(chord: "G", text: "two")
            ])
        ])
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for client request")
    }
}

private struct FixedPracticeClock: AudioHostClock {
    func nowSeconds() -> Double { 100 }
    func seconds(forHostTime hostTime: UInt64) -> Double { 100 }
}

private actor SuspendedPracticeClient: ChordWikiClientProtocol {
    private var calls = 0
    private var chartContinuation: CheckedContinuation<ChordChart, Error>?
    private var searchContinuation: CheckedContinuation<[ChordWikiSearchResult], Error>?

    func search(query: String) async throws -> [ChordWikiSearchResult] {
        calls += 1
        return try await withCheckedThrowingContinuation { searchContinuation = $0 }
    }

    func loadChart(_ result: ChordWikiSearchResult) async throws -> ChordChart {
        calls += 1
        return try await withCheckedThrowingContinuation { chartContinuation = $0 }
    }

    func callCount() -> Int { calls }
    func hasChartRequest() -> Bool { chartContinuation != nil }
    func hasSearchRequest() -> Bool { searchContinuation != nil }

    func finishChart(_ chart: ChordChart) {
        chartContinuation?.resume(returning: chart)
        chartContinuation = nil
    }

    func finishSearch(_ results: [ChordWikiSearchResult]) {
        searchContinuation?.resume(returning: results)
        searchContinuation = nil
    }
}
