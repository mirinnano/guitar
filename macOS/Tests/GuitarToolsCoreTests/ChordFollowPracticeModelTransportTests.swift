import Foundation
import XCTest
import GuitarToolsCore
@testable import GuitarToolsMacApp

@MainActor
final class ChordFollowPracticeModelTransportTests: XCTestCase {
    func testBackwardSeekRearmsCompletedChordWithoutDiscardingHistory() async throws {
        let (model, audio, clock) = makeModel()
        model.loadPractice(ChartPracticeRequest(chart: makeChart(), beat: 0, bpm: 120))
        model.play()
        defer { model.pause() }
        try await playChord("C", at: 100, audio: audio, model: model, attemptCount: 1)

        clock.set(101.5)
        model.pause()
        model.seek(to: 0)
        XCTAssertEqual(model.attempts.count, 1)
        model.play()
        try await playChord("C", at: 101.5, audio: audio, model: model, attemptCount: 2)

        XCTAssertEqual(model.attempts.map(\.eventID), [0, 0])
        XCTAssertEqual(model.attempts.map(\.expectedChord), ["C", "C"])
        XCTAssertEqual(model.lastAttempt?.timingErrorMs ?? .infinity, 0, accuracy: 0.001)
    }

    func testBackwardSeekWhilePlayingRearmsDestinationChord() async throws {
        let (model, audio, clock) = makeModel()
        model.loadPractice(ChartPracticeRequest(chart: makeChart(), beat: 0, bpm: 120))
        model.play()
        defer { model.pause() }
        try await playChord("C", at: 100, audio: audio, model: model, attemptCount: 1)
        clock.set(101)
        try await playChord("G", at: 101, audio: audio, model: model, attemptCount: 2)

        clock.set(101.5)
        // The model's timer need not have published 1.5s yet: seek samples the clock.
        model.seek(to: 1)
        try await playChord("G", at: 101.5, audio: audio, model: model, attemptCount: 3)
        XCTAssertEqual(model.attempts.map(\.eventID), [0, 1, 1])
        XCTAssertEqual(model.lastAttempt?.timingErrorMs ?? .infinity, 0, accuracy: 0.001)
    }

    func testBackwardSeekCancelsPendingAttemptAndReleasesItsClaim() async throws {
        let (model, audio, clock) = makeModel()
        model.loadPractice(ChartPracticeRequest(chart: makeChart(), beat: 0, bpm: 120))
        model.play()
        defer { model.pause() }
        audio.onOnset?(onset(at: 100))
        try await waitUntil { model.pendingExpected?.id == 0 }

        clock.set(100.25)
        model.seek(to: 0)
        XCTAssertNil(model.pendingExpected)
        audio.onStableChord?("C", 100.1)
        try await drainAudioCallbacks()
        XCTAssertTrue(model.attempts.isEmpty, "Do not finalize the pre-seek onset")

        try await playChord("C", at: 100.25, audio: audio, model: model, attemptCount: 1)
        XCTAssertEqual(model.lastAttempt?.eventID, 0)
    }

    func testPausePreservesLoadedChartPositionTempoAndCompletedAttempts() async throws {
        let (model, audio, clock) = makeModel()
        let chart = makeChart()
        model.loadPractice(ChartPracticeRequest(chart: chart, beat: 0, bpm: 84))
        let timeline = try XCTUnwrap(model.timeline)
        model.play()
        defer { model.pause() }
        try await playChord("C", at: 100, audio: audio, model: model, attemptCount: 1)
        let attempts = model.attempts
        let lastAttempt = model.lastAttempt
        clock.set(100.75)

        model.pause()
        XCTAssertFalse(model.isPlaying)
        XCTAssertEqual(model.chart, chart)
        XCTAssertEqual(model.timeline, timeline)
        XCTAssertEqual(model.currentSeconds, 0.75, accuracy: 0.001)
        XCTAssertEqual(model.bpm, 84)
        XCTAssertEqual(model.attempts, attempts)
        XCTAssertEqual(model.lastAttempt, lastAttempt)

        clock.set(101.5)
        model.pause()
        XCTAssertEqual(model.currentSeconds, 0.75, accuracy: 0.001, "Already-paused navigation must not advance time")
    }

    func testPauseCancelsPendingGradingAndReleasesClaimForResume() async throws {
        let (model, audio, clock) = makeModel()
        model.loadPractice(ChartPracticeRequest(chart: makeChart(), beat: 0, bpm: 120))
        model.play()
        defer { model.pause() }
        audio.onOnset?(onset(at: 100))
        try await waitUntil { model.pendingExpected?.id == 0 }

        clock.set(100.1)
        model.pause()
        XCTAssertNil(model.pendingExpected)
        audio.onStableChord?("C", 100.1)
        try await drainAudioCallbacks()
        XCTAssertTrue(model.attempts.isEmpty, "Hidden/paused practice must not grade")
        XCTAssertEqual(model.currentSeconds, 0.1, accuracy: 0.001)

        model.play()
        try await playChord("C", at: 100.1, audio: audio, model: model, attemptCount: 1)
        XCTAssertEqual(model.lastAttempt?.eventID, 0)
    }

    func testForwardSeekAlsoCancelsPendingEvaluation() async throws {
        let (model, audio, clock) = makeModel()
        model.loadPractice(ChartPracticeRequest(chart: makeChart(), beat: 0, bpm: 120))
        model.play()
        defer { model.pause() }
        audio.onOnset?(onset(at: 100))
        try await waitUntil { model.pendingExpected?.id == 0 }

        clock.set(100.1)
        model.seek(to: 1)
        XCTAssertNil(model.pendingExpected)
        audio.onStableChord?("C", 100.08)
        try await drainAudioCallbacks()
        XCTAssertTrue(model.attempts.isEmpty)

        try await playChord("G", at: 100.1, audio: audio, model: model, attemptCount: 1)
        XCTAssertEqual(model.lastAttempt?.eventID, 1)
    }

    func testUnsafeTimingSlotIsNeverScoredButPlayableNeighborKeepsItsOnset() async throws {
        let (model, audio, clock) = makeModel()
        let chart = ChordChartParser.parse(
            "{capo:2}\n[Cm((7)]one [G]two",
            fallbackTitle: "Unsafe conversion"
        )
        model.loadPractice(ChartPracticeRequest(chart: chart, beat: 0, bpm: 120))
        let events = try XCTUnwrap(model.timeline).events
        XCTAssertEqual(events.count, 2)
        XCTAssertFalse(events[0].isPlayable)
        XCTAssertEqual(events[1].startBeat, 2)
        model.play()
        defer { model.pause() }

        audio.onOnset?(onset(at: 100))
        audio.onStableChord?("Cm", 100.1)
        try await drainAudioCallbacks()
        XCTAssertNil(model.pendingExpected)
        XCTAssertTrue(model.attempts.isEmpty)

        clock.set(101)
        try await playChord("A", at: 101, audio: audio, model: model, attemptCount: 1)
        XCTAssertEqual(model.lastAttempt?.eventID, events[1].id)
        XCTAssertEqual(model.lastAttempt?.expectedChord, "A")
        XCTAssertEqual(model.lastAttempt?.timingErrorMs ?? .infinity, 0, accuracy: 0.001)
    }

    func testLastSearchQueryRecordsSubmittedTrimmedQueryNotLiveTyping() async throws {
        let (model, _, _) = makeModel()
        XCTAssertNil(model.lastSearchQuery)
        model.query = " \n "
        model.search()
        XCTAssertNil(model.lastSearchQuery)

        model.query = "  Missing song\n"
        model.search()
        XCTAssertEqual(model.lastSearchQuery, "Missing song")
        model.query = "Still typing"
        try await waitUntil { !model.isSearching }
        XCTAssertTrue(model.searchResults.isEmpty)
        XCTAssertEqual(model.lastSearchQuery, "Missing song")
    }

    private func makeModel() -> (ChordFollowPracticeModel, AudioInputModel, TransportClock) {
        let suite = "ChordFollowPracticeModelTransportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let clock = TransportClock()
        let audio = AudioInputModel(clock: clock)
        let model = ChordFollowPracticeModel(
            audio: audio,
            preferencesStore: AppPreferencesStore(defaults: defaults),
            clock: clock,
            sessionStore: PracticeSessionStore(directoryURL: directory),
            client: TransportClient(),
            requestAudioStart: {} // Synthetic callbacks; never request microphone access.
        )
        return (model, audio, clock)
    }

    private func makeChart() -> ChordChart {
        ChordChart(sourceTitle: "Song", title: "Song", lines: [
            ChartLine(segments: [
                ChartSegment(chord: "C", text: "one"),
                ChartSegment(chord: "G", text: "two")
            ])
        ])
    }

    private func onset(at timestamp: Double) -> AudioOnset {
        AudioOnset(timestampSeconds: timestamp, sampleOffset: 0, levelDBFS: -20, riseDB: 12)
    }

    private func playChord(
        _ chord: String,
        at timestamp: Double,
        audio: AudioInputModel,
        model: ChordFollowPracticeModel,
        attemptCount: Int
    ) async throws {
        audio.onOnset?(onset(at: timestamp))
        try await waitUntil { model.pendingExpected != nil }
        audio.onStableChord?(chord, timestamp + 0.1)
        try await waitUntil { model.attempts.count == attemptCount }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for practice model")
    }

    private func drainAudioCallbacks() async throws {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

private final class TransportClock: AudioHostClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value = 100.0

    func set(_ value: Double) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func nowSeconds() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func seconds(forHostTime hostTime: UInt64) -> Double { nowSeconds() }
}

private struct TransportClient: ChordWikiClientProtocol {
    func search(query: String) async throws -> [ChordWikiSearchResult] { [] }
    func loadChart(_ result: ChordWikiSearchResult) async throws -> ChordChart {
        ChordChart(sourceTitle: result.title, title: result.title, lines: [])
    }
}
