import Combine
import XCTest
import GuitarToolsCore
@testable import GuitarToolsMacApp

@MainActor
final class ChordWikiViewerModelSearchTests: XCTestCase {

    func testSubmittingSearchFromAnOpenChartShowsFreshResults() async throws {
        let chart = ChordChart(
            sourceTitle: "Previous song",
            title: "Previous song",
            lines: []
        )
        let expectedResult = ChordWikiSearchResult(
            title: "Different song",
            url: URL(string: "https://ja.chordwiki.org/wiki/Different")!
        )
        let client = StubChordWikiClient(
            chart: chart,
            results: [expectedResult]
        )
        let model = ChordWikiViewerModel(client: client)

        model.open(
            ChordWikiSearchResult(
                title: "Previous song",
                url: URL(string: "https://ja.chordwiki.org/wiki/Previous")!
            )
        )
        try await waitUntil {
            model.chart?.title == "Previous song"
        }

        model.query = "Different song"
        model.search()

        XCTAssertNil(model.chart)
        XCTAssertTrue(model.isSearching)

        try await waitUntil {
            !model.isSearching
        }

        XCTAssertEqual(
            model.results.map(\.title),
            ["Different song"]
        )
        let queries = await client.requestedQueries()
        XCTAssertEqual(queries, ["Different song"])
    }

    func testLastSearchQueryRecordsSubmittedTrimmedQueryNotLiveTyping() async throws {
        let client = StubChordWikiClient(
            chart: ChordChart(sourceTitle: "Song", title: "Song", lines: []),
            results: []
        )
        let model = ChordWikiViewerModel(client: client)
        XCTAssertNil(model.lastSearchQuery)
        model.query = " \n "
        model.search()
        XCTAssertNil(model.lastSearchQuery)

        model.query = "  Missing song\n"
        model.search()
        XCTAssertEqual(model.lastSearchQuery, "Missing song")
        model.query = "Still typing"
        try await waitUntil { !model.isSearching }
        XCTAssertTrue(model.results.isEmpty)
        XCTAssertEqual(model.lastSearchQuery, "Missing song")
        let queries = await client.requestedQueries()
        XCTAssertEqual(queries, ["Missing song"])
    }

    func testCanAttachMusicToChartWithoutVideo() async throws {
        let client = StubChordWikiClient(
            chart: ChordChart(sourceTitle: "Song", title: "Song", lines: []),
            results: []
        )
        let model = ChordWikiViewerModel(client: client)
        model.open(ChordWikiSearchResult(
            title: "Song",
            url: URL(string: "https://ja.chordwiki.org/wiki/Song")!
        ))
        try await waitUntil { model.chart != nil }

        XCTAssertNil(model.youtubeVideoID)
        model.attachMusicURL("https://youtu.be/j7CDb610Bg0")
        XCTAssertEqual(model.youtubeVideoID, "j7CDb610Bg0")
        XCTAssertTrue(model.youtubeSyncEnabled)
        XCTAssertNil(model.musicMessage)

        model.attachMusicURL("https://example.com/not-a-video")
        XCTAssertEqual(model.youtubeVideoID, "j7CDb610Bg0")
        XCTAssertNotNil(model.musicMessage)

        model.musicUnavailable()
        XCTAssertFalse(model.youtubeSyncEnabled)
        XCTAssertNotNil(model.musicMessage)

        model.close()
        XCTAssertNil(model.youtubeVideoID)
        XCTAssertFalse(model.youtubeSyncEnabled)
    }

    func testVideoLoopRequestsOneSeekAndRearmsAfterReturningToStart() async throws {
        let model = try await makeLoopModel()
        model.setLoopEnabled(true)
        model.onYouTubeProgress(positionMs: 9_000, durationMs: 60_000, playing: true, rate: 1)
        XCTAssertEqual(model.loopRestartRevision, 1)
        XCTAssertEqual(model.currentBeat, 0)
        model.onYouTubeProgress(positionMs: 9_000, durationMs: 60_000, playing: true, rate: 1)
        XCTAssertEqual(model.loopRestartRevision, 1)
        model.onYouTubeProgress(positionMs: 500, durationMs: 60_000, playing: true, rate: 1)
        model.onYouTubeProgress(positionMs: 9_000, durationMs: 60_000, playing: true, rate: 1)
        XCTAssertEqual(model.loopRestartRevision, 2)
        model.stop()
    }

    func testPausedVideoDoesNotRestartAtLoopEnd() async throws {
        let model = try await makeLoopModel()
        model.setLoopEnabled(true)
        model.stop()
        model.onYouTubeProgress(positionMs: 9_000, durationMs: 60_000, playing: false, rate: 1)
        XCTAssertEqual(model.loopRestartRevision, 0)
        XCTAssertFalse(model.isPlaying)
    }

    func testStopPreservesLoadedChartPositionLoopAndSelectedTempo() async throws {
        let model = try await makeLoopModel()
        defer { model.stop() }
        model.bpm = 84
        model.seek(beat: 8)
        model.useFourBarLoop()
        model.onYouTubeProgress(
            positionMs: model.videoPosition(forBeat: 12),
            durationMs: 60_000,
            playing: true,
            rate: 0.75
        )
        XCTAssertTrue(model.isPlaying)
        let chart = try XCTUnwrap(model.chart)
        let timeline = try XCTUnwrap(model.timeline)
        let loop = try XCTUnwrap(model.practiceLoop)
        let beat = model.currentBeat
        let videoPosition = model.youtubePositionMs

        model.stop()

        XCTAssertFalse(model.isPlaying)
        XCTAssertFalse(model.youtubePlaying)
        XCTAssertNil(model.countInRemaining)
        XCTAssertEqual(model.chart, chart)
        XCTAssertEqual(model.timeline, timeline)
        XCTAssertEqual(model.currentBeat, beat)
        XCTAssertEqual(model.youtubePositionMs, videoPosition)
        XCTAssertEqual(model.practiceLoop, loop)
        XCTAssertTrue(model.loopEnabled)
        XCTAssertEqual(model.bpm, 84)
        XCTAssertEqual(model.youtubePlaybackRate, 0.75)
    }

    func testDuplicatePausedVideoSamplesDoNotPublishChanges() async throws {
        let model = try await makeLoopModel()
        defer { model.stop() }
        model.onYouTubeProgress(positionMs: 500, durationMs: 60_000, playing: false, rate: 0.75)
        var emissions = 0
        let subscription = model.objectWillChange.sink { emissions += 1 }
        defer { subscription.cancel() }

        for _ in 0..<10 {
            model.onYouTubeProgress(positionMs: 500, durationMs: 60_000, playing: false, rate: 0.75)
        }
        XCTAssertEqual(emissions, 0)
        XCTAssertEqual(model.currentBeat, 1)
        XCTAssertFalse(model.isPlaying)

        model.onYouTubeProgress(positionMs: 1_000, durationMs: 60_000, playing: false, rate: 0.75)
        XCTAssertGreaterThan(emissions, 0, "Changed samples must still update the UI")
        XCTAssertEqual(model.currentBeat, 2)
        let changedEmissions = emissions
        model.onYouTubeProgress(positionMs: 1_000, durationMs: 60_000, playing: false, rate: 0.75)
        XCTAssertEqual(emissions, changedEmissions)
    }

    func testCountInCanBeDisabledForImmediatePlayback() async throws {
        let model = try await makeLoopModel()
        model.countInEnabled = false
        var started = false
        model.beginPlayback { started = true }
        XCTAssertTrue(started)
        XCTAssertNil(model.countInRemaining)
    }

    func testCountInRestartsAtSongBeginningDespitePausedVideoReports() async throws {
        let model = try await makeLoopModel()
        defer { model.stop() }
        model.bpm = 300
        let totalBeats = try XCTUnwrap(model.timeline).totalBeats
        let endPosition = model.videoPosition(forBeat: totalBeats)
        model.onYouTubeProgress(positionMs: endPosition, durationMs: 60_000, playing: false, rate: 1)
        XCTAssertEqual(model.currentBeat, totalBeats)

        var startedAt: Double?
        model.beginPlayback { startedAt = model.currentBeat }
        // Covers the gap before the count-in Task publishes its first beat too.
        model.onYouTubeProgress(positionMs: endPosition, durationMs: 60_000, playing: false, rate: 1)
        XCTAssertEqual(model.currentBeat, 0)
        try await waitUntil { model.countInRemaining != nil }
        model.onYouTubeProgress(positionMs: endPosition, durationMs: 60_000, playing: false, rate: 1)
        XCTAssertEqual(model.currentBeat, 0)

        try await waitUntil(iterations: 300) { startedAt != nil }
        XCTAssertEqual(try XCTUnwrap(startedAt), 0)
        XCTAssertEqual(model.youtubePositionMs, model.videoPosition(forBeat: 0))
        XCTAssertNil(model.countInRemaining)
    }

    func testCountInPreservesNonzeroLoopStartDespiteOldVideoReports() async throws {
        let model = try await makeLoopModel()
        defer { model.stop() }
        model.bpm = 300
        model.seek(beat: 8)
        model.setLoopStart()
        model.setLoopEnabled(true)
        let range = try XCTUnwrap(model.practiceLoop)
        XCTAssertEqual(range.startBeat, 8)
        let outsidePosition = model.videoPosition(forBeat: range.endBeat + 1)
        model.onYouTubeProgress(positionMs: outsidePosition, durationMs: 60_000, playing: false, rate: 1)

        var startedAt: Double?
        model.beginPlayback { startedAt = model.currentBeat }
        model.onYouTubeProgress(positionMs: outsidePosition, durationMs: 60_000, playing: false, rate: 1)
        XCTAssertEqual(model.currentBeat, range.startBeat)
        XCTAssertEqual(model.loopRestartRevision, 0)
        try await waitUntil(iterations: 300) { startedAt != nil }
        XCTAssertEqual(try XCTUnwrap(startedAt), range.startBeat)
    }

    func testStoppingCountInCancelsItsTargetAndAllowsProgressAgain() async throws {
        let model = try await makeLoopModel()
        defer { model.stop() }
        model.bpm = 300
        var started = false
        model.beginPlayback { started = true }
        try await waitUntil { model.countInRemaining != nil }
        model.stop()
        model.onYouTubeProgress(positionMs: 1_000, durationMs: 60_000, playing: false, rate: 1)
        XCTAssertEqual(model.currentBeat, 5)
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(started)
        XCTAssertNil(model.countInRemaining)
    }

    func testCoachReturnPreparesExactSourceRangeWithoutChangingSongTempo() async throws {
        let model = try await makeLoopModel()
        model.startInternal()
        model.prepareTransitionLoop(startBeat: 8, endBeat: 16)
        XCTAssertEqual(model.currentBeat, 8)
        XCTAssertEqual(model.practiceLoop?.startBeat, 8)
        XCTAssertEqual(model.practiceLoop?.endBeat, 16)
        XCTAssertTrue(model.loopEnabled)
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.bpm, 120)
        XCTAssertNil(model.countInRemaining)
        model.prepareTransitionLoop(startBeat: 20, endBeat: 10)
        XCTAssertEqual(model.practiceLoop?.startBeat, 8)
        XCTAssertEqual(model.currentBeat, 8)
        model.stop()
    }

    private func makeLoopModel() async throws -> ChordWikiViewerModel {
        let chart = ChordChartParser.parse(
            "{tempo:120}\n{youtube:j7CDb610Bg0}\n" + String(repeating: "[C]one [G]two [Am]three [F]four\n", count: 8),
            fallbackTitle: "Song"
        )
        let model = ChordWikiViewerModel(client: StubChordWikiClient(chart: chart, results: []))
        model.open(ChordWikiSearchResult(title: "Song", url: URL(string: "https://ja.chordwiki.org/wiki/Song")!))
        try await waitUntil { model.chart != nil }
        return model
    }

    private func waitUntil(
        iterations: Int = 100,
        _ condition: () -> Bool
    ) async throws {
        for _ in 0..<iterations {
            if condition() {
                return
            }

            try await Task.sleep(
                nanoseconds: 10_000_000
            )
        }

        XCTFail("Timed out waiting for the model state")
    }
}

private actor StubChordWikiClient: ChordWikiClientProtocol {

    private let chart: ChordChart
    private let results: [ChordWikiSearchResult]
    private var queries: [String] = []

    init(
        chart: ChordChart,
        results: [ChordWikiSearchResult]
    ) {
        self.chart = chart
        self.results = results
    }

    func search(
        query: String
    ) async throws -> [ChordWikiSearchResult] {
        queries.append(query)
        return results
    }

    func loadChart(
        _ result: ChordWikiSearchResult
    ) async throws -> ChordChart {
        chart
    }

    func requestedQueries() -> [String] {
        queries
    }
}
