import Foundation
import XCTest
import GuitarToolsCore
@testable import GuitarToolsMacApp

@MainActor
final class SongCoachModelTests: XCTestCase {
    func testStartsWithOneSourceBarCountInAndAlternatesEachBar() async throws {
        let h = makeHarness(chart: makeChart(beatsPerBar: 3))
        XCTAssertEqual(h.model.phase, .ready)
        XCTAssertFalse(h.model.isActive)
        XCTAssertFalse(h.model.canRate)
        XCTAssertEqual(h.model.bpm, 66)
        h.model.start()
        XCTAssertEqual(h.model.phase, .countIn)
        XCTAssertEqual(h.clicker.configs.last?.countInBars, 1)
        XCTAssertEqual(h.clicker.configs.last?.beatsPerBar, 3)
        XCTAssertEqual(h.model.countInRemaining, 3)
        for beat in 0..<3 {
            h.clicker.emit(beat: beat, countIn: true)
            XCTAssertEqual(h.model.beatInChord, beat)
            XCTAssertEqual(h.model.countInRemaining, 3 - beat)
            XCTAssertEqual(h.model.activeChordIndex, 0)
        }
        XCTAssertEqual(h.model.phase, .countIn)
        XCTAssertEqual(h.model.countInRemaining, 1)
        XCTAssertEqual(h.model.secondsRemaining, 30)
        XCTAssertFalse(h.model.canRate)

        for index in 0..<7 {
            h.clicker.emit(beat: index % 3)
            XCTAssertEqual(h.model.activeChordIndex, (index / 3) % 2)
            XCTAssertEqual(h.model.beatInChord, index % 3)
        }
        XCTAssertEqual(h.model.phase, .playing)
        XCTAssertNil(h.model.countInRemaining)
        XCTAssertTrue(h.model.isActive)
        h.model.stop()
    }

    func testPausePreservesElapsedAndResumeExcludesPauseAndSecondCountIn() async {
        let h = makeHarness()
        h.model.start()
        h.clock.set(120)
        h.clicker.emit()
        h.clock.set(125)
        h.model.pause()
        XCTAssertEqual(h.model.phase, .paused)
        XCTAssertEqual(h.model.secondsRemaining, 25, accuracy: 0.001)
        XCTAssertTrue(h.model.canRate)
        h.clock.set(500)
        h.model.start()
        h.clicker.emit(countIn: true)
        h.clock.set(520)
        XCTAssertEqual(h.model.secondsRemaining, 25)
        h.clicker.emit()
        h.clock.set(544.9)
        h.ticker.fire()
        XCTAssertEqual(h.model.phase, .playing)
        XCTAssertEqual(h.model.secondsRemaining, 0.1, accuracy: 0.001)
        h.clock.set(545)
        h.ticker.fire()
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertEqual(h.model.secondsRemaining, 0)
        XCTAssertEqual(h.model.progress.totalRounds, 1)
    }

    func testResumeMidBarOrAtBoundaryAlignsPreparedChordWithFreshAccentedBar() async throws {
        // Both chords, every mid-bar position, and both completed-bar boundaries.
        for playedPulses in 1...8 {
            let h = makeHarness()
            h.model.start()
            for index in 0..<playedPulses { h.clicker.emit(beat: index % 4) }
            h.clock.set(104)
            h.model.pause()
            XCTAssertEqual(h.model.secondsRemaining, 26)
            let staleBeat = h.clicker.beatHandlers.last!
            h.clock.set(200)
            h.model.start()
            let preparedChord = (playedPulses / 4) % 2
            XCTAssertEqual(h.model.activeChordIndex, preparedChord)
            XCTAssertEqual(h.model.beatInChord, 0)
            let config = try XCTUnwrap(h.clicker.configs.last)
            XCTAssertEqual(config.accents, [.accent, .normal, .normal, .normal])
            for beat in 0..<4 {
                h.clicker.emit(beat: beat, countIn: true)
                XCTAssertEqual(h.model.beatInChord, beat)
                XCTAssertEqual(h.model.activeChordIndex, preparedChord)
                XCTAssertEqual(h.model.countInRemaining, 4 - beat)
                XCTAssertEqual(h.model.secondsRemaining, 26)
            }
            staleBeat(event())
            XCTAssertEqual(h.model.phase, .countIn)
            XCTAssertEqual(h.model.beatInChord, 3)
            // After count-in, every chord gets all four beats, with its first beat
            // coinciding with the engine's configured downbeat accent.
            for index in 0..<9 {
                let beat = index % 4
                h.clicker.emit(beat: beat)
                XCTAssertEqual(h.model.beatInChord, beat)
                XCTAssertEqual(h.model.activeChordIndex, (preparedChord + index / 4) % 2)
                if beat == 0 { XCTAssertEqual(config.accents[beat], .accent) }
            }
            XCTAssertEqual(h.model.secondsRemaining, 26)
            h.model.stop()
        }
    }

    func testPausingResumedCountInKeepsPreparedChordAndRestartsBeatZero() async {
        let h = makeHarness()
        h.model.start()
        for beat in 0..<4 { h.clicker.emit(beat: beat) }
        h.clock.set(103)
        h.model.pause()
        h.model.start()
        XCTAssertEqual(h.model.activeChordIndex, 1)
        h.clicker.emit(beat: 2, countIn: true)
        XCTAssertEqual(h.model.beatInChord, 2)
        h.model.pause()
        h.clock.set(500)
        h.model.start()
        XCTAssertEqual(h.model.activeChordIndex, 1)
        XCTAssertEqual(h.model.beatInChord, 0)
        XCTAssertEqual(h.model.countInRemaining, 4)
        h.clicker.emit(beat: 0, countIn: true)
        XCTAssertEqual(h.model.beatInChord, 0)
        h.clicker.emit(beat: 0)
        XCTAssertEqual(h.model.activeChordIndex, 1)
        XCTAssertEqual(h.model.beatInChord, 0)
        XCTAssertEqual(h.model.secondsRemaining, 27)
        h.model.stop()
    }

    func testPauseDuringCountInCancelsOldBeatAndOldError() async {
        let h = makeHarness()
        h.model.start()
        let staleBeat = h.clicker.beatHandlers[0]
        let staleError = h.clicker.errorHandlers[0]
        h.model.pause()
        XCTAssertEqual(h.model.phase, .paused)
        XCTAssertNil(h.model.countInRemaining)
        XCTAssertFalse(h.model.canRate)
        staleBeat(event())
        staleError(TestError())
        XCTAssertEqual(h.model.phase, .paused)
        XCTAssertNil(h.model.soundError)
        h.model.start()
        staleBeat(event())
        XCTAssertEqual(h.model.phase, .countIn)
        h.clicker.emit()
        XCTAssertEqual(h.model.phase, .playing)
        h.model.stop()
    }

    func testStopRejectsQueuedBeatsAndTicksIncludingAfterRestart() async {
        let h = makeHarness()
        h.model.start()
        h.clicker.emit()
        let staleBeat = h.clicker.beatHandlers[0]
        let staleTick = h.ticker.handlers[0]
        h.clock.set(103)
        h.model.stop()
        staleBeat(event())
        staleTick()
        XCTAssertEqual(h.model.phase, .ready)
        XCTAssertEqual(h.model.secondsRemaining, 30)
        XCTAssertFalse(h.model.canRate)
        h.model.start()
        staleBeat(event())
        staleTick()
        XCTAssertEqual(h.model.phase, .countIn)
        h.clicker.emit()
        h.clock.set(120)
        staleTick()
        XCTAssertEqual(h.model.secondsRemaining, 30)
        h.ticker.fire()
        XCTAssertEqual(h.model.secondsRemaining, 13)
        h.model.stop()
    }

    func testCompletesAtThirtyActiveSecondsAndCountsRoundOnlyOnce() async {
        let h = makeHarness()
        h.model.start()
        h.clock.set(999)
        h.clicker.emit(countIn: true)
        h.ticker.fire()
        XCTAssertEqual(h.model.secondsRemaining, 30)
        h.clicker.emit()
        h.clock.set(1028.99)
        h.ticker.fire()
        XCTAssertEqual(h.model.phase, .playing)
        h.clock.set(1029)
        h.ticker.fire()
        XCTAssertEqual(h.model.phase, .completed)
        XCTAssertFalse(h.model.isActive)
        XCTAssertTrue(h.model.canRate)
        XCTAssertFalse(h.clicker.running)
        XCTAssertFalse(h.ticker.running)
        h.ticker.fire()
        h.clicker.emit()
        h.model.rateComfortable()
        h.model.rateDifficult()
        XCTAssertEqual(h.model.progress.totalRounds, 1)
        XCTAssertEqual(h.model.progress.comfortableRounds, 1)
        XCTAssertEqual(h.model.bpm, 71)
        XCTAssertTrue(h.model.feedbackMessage?.hasPrefix("次は71 BPMで。") == true)
        XCTAssertEqual(h.model.feedbackMessage?.components(separatedBy: "自己チェック").count, 2)
        XCTAssertFalse(h.model.canRate)
        h.model.start()
        XCTAssertEqual(h.model.phase, .countIn)
        XCTAssertEqual(h.model.secondsRemaining, 30)
        h.model.stop()
    }

    func testRatingRequiresPositivePracticeAndCannotBeRepeated() async {
        let h = makeHarness()
        h.model.rateComfortable()
        h.model.start()
        h.model.rateDifficult()
        XCTAssertEqual(h.model.progress.totalRounds, 0)
        h.clicker.emit()
        XCTAssertFalse(h.model.canRate)
        h.clock.set(101)
        h.ticker.fire()
        XCTAssertTrue(h.model.canRate)
        h.model.rateDifficult()
        XCTAssertEqual(h.model.phase, .paused)
        XCTAssertEqual(h.model.bpm, 56)
        XCTAssertEqual(h.model.progress.totalRounds, 1)
        XCTAssertEqual(h.model.progress.comfortableRounds, 0)
        XCTAssertTrue(h.model.feedbackMessage?.hasPrefix("56 BPMに下げました。") == true)
        XCTAssertEqual(h.model.feedbackMessage?.components(separatedBy: "自己チェック").count, 2)
        h.model.rateComfortable()
        XCTAssertEqual(h.model.bpm, 56)
        XCTAssertEqual(h.model.progress.totalRounds, 1)
        h.model.start()
        XCTAssertEqual(h.model.secondsRemaining, 30)
        h.clicker.emit()
        h.clock.set(102)
        h.ticker.fire()
        XCTAssertTrue(h.model.canRate)
        h.model.stop()
    }

    func testTempoClampAdaptationAndSourceSongIsUnchanged() async {
        let h = makeHarness(sourceBPM: 100)
        XCTAssertEqual(h.model.bpm, 55)
        XCTAssertEqual(h.model.goalBPM, 100)
        h.model.setBPM(Int.min)
        XCTAssertEqual(h.model.bpm, 40)
        h.model.setBPM(Int.max)
        XCTAssertEqual(h.model.bpm, 300)
        practiceAndRate(h, comfortable: true)
        XCTAssertEqual(h.model.bpm, 300, "Positive feedback must respect an explicitly faster tempo")
        h.model.setBPM(98)
        practiceAndRate(h, comfortable: true)
        XCTAssertEqual(h.model.bpm, 100)
        practiceAndRate(h, comfortable: true)
        XCTAssertEqual(h.model.bpm, 100)
        h.model.setBPM(42)
        practiceAndRate(h, comfortable: false)
        XCTAssertEqual(h.model.bpm, 40)
        XCTAssertEqual(h.model.chart.bpm, 120)
        XCTAssertEqual(makeHarness(sourceBPM: Int.min).model.goalBPM, 40)
        let fast = makeHarness(sourceBPM: Int.max)
        XCTAssertEqual(fast.model.goalBPM, 300)
        XCTAssertEqual(fast.model.bpm, 80)
    }

    func testTempoEditDuringPlaybackPreservesTimeAndRestartsCountIn() async {
        let h = makeHarness()
        h.model.start()
        h.clicker.emit()
        h.clock.set(104)
        h.model.setBPM(80)
        XCTAssertEqual(h.model.phase, .countIn)
        XCTAssertEqual(h.model.secondsRemaining, 26)
        XCTAssertEqual(h.clicker.configs.last?.bpm, 80)
        h.clock.set(200)
        h.clicker.emit()
        h.clock.set(201)
        h.ticker.fire()
        XCTAssertEqual(h.model.secondsRemaining, 25)
        h.model.stop()
    }

    func testPairSelectionResetsRoundAndRestoresIndependentProgress() async throws {
        let h = makeHarness()
        let first = try XCTUnwrap(h.model.selectedID)
        let second = try XCTUnwrap(h.model.plan.transitions.first { $0.id != first }?.id)
        h.model.setBPM(79)
        practiceAndRate(h, comfortable: true)
        XCTAssertEqual(h.model.bpm, 84)
        h.model.start()
        let stale = h.clicker.beatHandlers.last!
        h.clicker.emit()
        h.clock.set(108)
        h.ticker.fire()
        h.model.select(second)
        XCTAssertEqual(h.model.phase, .ready)
        XCTAssertEqual(h.model.secondsRemaining, 30)
        XCTAssertEqual(h.model.activeChordIndex, 0)
        XCTAssertEqual(h.model.beatInChord, 0)
        XCTAssertEqual(h.model.bpm, 66)
        XCTAssertEqual(h.model.progress.totalRounds, 0)
        XCTAssertNil(h.model.feedbackMessage)
        stale(event())
        XCTAssertEqual(h.model.phase, .ready)
        h.model.setBPM(50)
        h.model.select(first)
        XCTAssertEqual(h.model.bpm, 84)
        XCTAssertEqual(h.model.progress.totalRounds, 1)
        XCTAssertEqual(h.model.progress.comfortableRounds, 1)
        h.model.select("not-a-pair")
        XCTAssertEqual(h.model.selectedID, first)
    }

    func testInitialPositionWinsOverSavedCandidateButBeginningRestoresIt() async throws {
        let h = makeHarness()
        let last = try XCTUnwrap(h.model.plan.transitions.first { $0.fromSymbol == "Am" })
        let first = try XCTUnwrap(h.model.plan.transitions.first { $0.fromSymbol == "C" })
        h.model.select(last.id)
        h.model.setBPM(77)
        let beginning = h.makeModel(initialBeat: 0)
        XCTAssertEqual(beginning.selectedID, last.id)
        XCTAssertEqual(beginning.bpm, 77)
        let positioned = h.makeModel(initialBeat: first.occurrenceBeats[0] + 0.01)
        XCTAssertEqual(positioned.selectedID, first.id)
        let nearLast = h.makeModel(initialBeat: last.occurrenceBeats[0])
        XCTAssertEqual(nearLast.selectedID, last.id)
        XCTAssertEqual(nearLast.bpm, 77)
    }

    func testVoicingPreferenceSnapshotPinsPlanAndSeparatesGeometrySpecificProgress() async throws {
        let h = makeHarness(chart: makeChart(symbols: ["C", "Am"]))
        let preferences = ChordVoicingPreferencesStore(defaults: h.defaults)
        let data = try XCTUnwrap(GuitarChordData(symbol: "C"))
        let choice = try XCTUnwrap(data.voicings.first { $0.shape.baseFret > 5 })
        preferences.select(choice.id, for: "CM")
        let snapshot = preferences.selections
        let selectedModel = h.makeModel(voicingSelections: snapshot)
        let selected = try XCTUnwrap(selectedModel.selectedTransition)
        XCTAssertEqual(selected.fromShape, choice.shape)
        XCTAssertTrue(selected.fixedFingers.isEmpty)
        XCTAssertEqual(selectedModel.plan, SongTransitionPlan(chart: h.chart, voicingSelections: snapshot))
        selectedModel.setBPM(77)
        XCTAssertEqual(h.makeModel(voicingSelections: snapshot).bpm, 77)

        // A changed global preference does not rebuild an already opened desk.
        preferences.select(nil, for: "C/C")
        XCTAssertTrue(preferences.selections.isEmpty)
        XCTAssertEqual(selectedModel.selectedTransition, selected)
        XCTAssertEqual(selectedModel.plan, SongTransitionPlan(chart: h.chart, voicingSelections: snapshot))
        let freshModel = h.makeModel(voicingSelections: preferences.selections)
        let standard = try XCTUnwrap(freshModel.selectedTransition)
        XCTAssertNotEqual(standard.id, selected.id)
        XCTAssertEqual(standard.fromShape, ChordFingeringPresentation(symbol: "C").shape)
        XCTAssertEqual(standard.fixedFingers.map(\.finger), [1, 2])
        XCTAssertEqual(freshModel.bpm, 66, "A different geometry must not inherit the pinned pair's saved BPM")
        XCTAssertEqual(freshModel.plan, h.model.plan, "Omitting selections retains the existing default behavior")
    }

    func testInvalidSelectedVoicingIDsKeepCoachDefaultPlan() async throws {
        let h = makeHarness(chart: makeChart(symbols: ["C", "Am"]))
        let cKey = try XCTUnwrap(GuitarChordData.selectionKey(for: "C"))
        let am = try XCTUnwrap(GuitarChordData(symbol: "Am"))
        for id in ["stale", am.voicings[0].id] {
            let model = h.makeModel(voicingSelections: [cKey: id])
            XCTAssertEqual(model.plan, h.model.plan)
            XCTAssertEqual(model.selectedTransition, h.model.selectedTransition)
        }
    }

    func testUnsupportedOrEmptyPlanNeverStartsClicker() async {
        for chart in [makeChart(symbols: []), makeChart(symbols: ["C"]),
                      makeChart(symbols: ["C", "NC", "G"]),
                      makeChart(symbols: ["not-a-chord", "C"])] {
            let h = makeHarness(chart: chart)
            XCTAssertTrue(h.model.plan.transitions.isEmpty)
            h.model.start()
            XCTAssertEqual(h.model.phase, .ready)
            XCTAssertNil(h.model.selectedID)
            XCTAssertTrue(h.clicker.configs.isEmpty)
            XCTAssertFalse(h.model.canRate)
        }
    }

    func testOutputErrorStopsTransportAndAllowsSafeRetry() async {
        let h = makeHarness()
        h.model.start()
        h.clicker.fail()
        XCTAssertEqual(h.model.phase, .ready)
        XCTAssertNotNil(h.model.soundError)
        XCTAssertFalse(h.clicker.running)
        h.model.start()
        XCTAssertNil(h.model.soundError)
        h.clicker.emit()
        h.clock.set(105)
        h.clicker.fail()
        XCTAssertEqual(h.model.phase, .paused)
        XCTAssertEqual(h.model.secondsRemaining, 25)
        XCTAssertTrue(h.model.canRate)
        h.model.stop()
    }

    func testProgressSaveReloadAndStableSongIdentity() async throws {
        let h = makeHarness()
        let id = try XCTUnwrap(h.model.selectedID)
        practiceAndRate(h, comfortable: true)
        let reloadedStore = SongCoachProgressStore(defaults: h.defaults)
        let saved = try XCTUnwrap(reloadedStore.progress(chart: h.chart, transitionID: id))
        XCTAssertEqual(saved, SongCoachProgress(bpm: 71, comfortableRounds: 1, totalRounds: 1))
        XCTAssertEqual(h.makeModel().progress, saved)
        XCTAssertNil(reloadedStore.progress(chart: makeChart(title: "Other"), transitionID: id))
        let url = URL(string: "https://example.invalid/song/1")!
        let original = makeChart(title: "Old title", sourceURL: url)
        let renamed = makeChart(title: "Renamed", sourceURL: url)
        reloadedStore.save(saved, chart: original, transitionID: id)
        XCTAssertEqual(reloadedStore.progress(chart: renamed, transitionID: id), saved)
        XCTAssertNotEqual(SongCoachProgressStore.songKey(makeChart(artist: "A")),
                          SongCoachProgressStore.songKey(makeChart(artist: "B")))
    }

    func testCorruptWrongVersionAndInvalidProgressAreIgnored() async {
        let h = makeHarness()
        for text in ["not JSON", "{\"version\":99,\"songs\":[]}",
                     "{\"version\":1,\"songs\":[{\"key\":\"bad\",\"pairs\":[{\"id\":\"pair\",\"progress\":{\"bpm\":10,\"comfortableRounds\":0,\"totalRounds\":0}}]}]}"] {
            h.defaults.set(Data(text.utf8), forKey: SongCoachProgressStore.storageKey)
            XCTAssertNil(h.store.selectedTransitionID(chart: h.chart))
            XCTAssertEqual(h.makeModel().bpm, 66)
        }
        h.model.setBPM(70)
        XCTAssertEqual(h.makeModel().bpm, 70, "A valid save replaces corrupt storage")
    }

    func testStorageRetainsLastFiftySongsAndLast128Pairs() async {
        let h = makeHarness()
        let progress = SongCoachProgress(bpm: 60)
        for index in 0..<52 {
            h.store.save(progress, chart: makeChart(title: "Song\(index)"), transitionID: "pair")
        }
        XCTAssertNil(h.store.progress(chart: makeChart(title: "Song0"), transitionID: "pair"))
        XCTAssertNotNil(h.store.progress(chart: makeChart(title: "Song2"), transitionID: "pair"))
        XCTAssertNotNil(h.store.progress(chart: makeChart(title: "Song51"), transitionID: "pair"))
        for index in 0..<130 {
            h.store.save(progress, chart: h.chart, transitionID: "pair\(index)")
        }
        XCTAssertNil(h.store.progress(chart: h.chart, transitionID: "pair0"))
        XCTAssertNotNil(h.store.progress(chart: h.chart, transitionID: "pair2"))
        XCTAssertNotNil(h.store.progress(chart: h.chart, transitionID: "pair129"))
        XCTAssertEqual(h.store.selectedTransitionID(chart: h.chart), "pair129")
    }

    private func practiceAndRate(_ h: Harness, comfortable: Bool) {
        h.model.start()
        h.clicker.emit()
        h.clock.set(h.clock.nowSeconds() + 1)
        h.ticker.fire()
        if comfortable { h.model.rateComfortable() } else { h.model.rateDifficult() }
    }

    private func makeHarness(chart: ChordChart? = nil, sourceBPM: Int = 120) -> Harness {
        let suite = "SongCoachModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return Harness(chart: chart ?? makeChart(), sourceBPM: sourceBPM, defaults: defaults)
    }

    private func makeChart(
        symbols: [String] = ["C", "G", "Am", "D7"],
        title: String = "Song", artist: String = "Artist",
        beatsPerBar: Int = 4, sourceURL: URL? = nil
    ) -> ChordChart {
        ChordChart(sourceTitle: title, title: title, artist: artist, bpm: 120,
                   beatsPerBar: beatsPerBar,
                   lines: [ChartLine(segments: symbols.map { ChartSegment(chord: $0, text: "word") })],
                   sourceURL: sourceURL)
    }

    private func event() -> MacBeatEvent {
        MacBeatEvent(beatInBar: 0, subdivisionIndex: 0, isCountIn: false, accent: .accent)
    }
}

@MainActor
private struct Harness {
    let chart: ChordChart
    let sourceBPM: Int
    let defaults: UserDefaults
    let store: SongCoachProgressStore
    let clicker = TestClicker()
    let ticker = TestTicker()
    let clock = CoachClock()
    let model: SongCoachModel

    init(chart: ChordChart, sourceBPM: Int, defaults: UserDefaults) {
        self.chart = chart
        self.sourceBPM = sourceBPM
        self.defaults = defaults
        store = SongCoachProgressStore(defaults: defaults)
        model = SongCoachModel(chart: chart, sourceBPM: sourceBPM, progressStore: store,
                               clicker: clicker, clock: clock, ticker: ticker)
    }

    func makeModel(initialBeat: Double = 0, voicingSelections: [String: String] = [:]) -> SongCoachModel {
        SongCoachModel(chart: chart, sourceBPM: sourceBPM, initialBeat: initialBeat,
                       voicingSelections: voicingSelections,
                       progressStore: store, clicker: TestClicker(), clock: CoachClock(), ticker: TestTicker())
    }
}

private final class TestClicker: SongCoachClicker {
    var configs: [MacMetronomeConfig] = []
    var beatHandlers: [@MainActor (MacBeatEvent) -> Void] = []
    var errorHandlers: [@MainActor (Error) -> Void] = []
    var running = false

    func start(config: MacMetronomeConfig,
               onBeat: @escaping @MainActor (MacBeatEvent) -> Void,
               onError: @escaping @MainActor (Error) -> Void) {
        configs.append(config)
        beatHandlers.append(onBeat)
        errorHandlers.append(onError)
        running = true
    }

    func stop() { running = false }

    @MainActor func emit(beat: Int = 0, countIn: Bool = false) {
        beatHandlers.last?(MacBeatEvent(beatInBar: beat, subdivisionIndex: 0,
                                       isCountIn: countIn, accent: .normal))
    }

    @MainActor func fail() { errorHandlers.last?(TestError()) }
}

private final class TestTicker: SongCoachTicker {
    var handlers: [@MainActor () -> Void] = []
    var running = false
    func start(onTick: @escaping @MainActor () -> Void) {
        handlers.append(onTick)
        running = true
    }
    func stop() { running = false }
    @MainActor func fire() { handlers.last?() }
}

private final class CoachClock: AudioHostClock, @unchecked Sendable {
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

private struct TestError: LocalizedError {
    var errorDescription: String? { "Test click output failed" }
}
