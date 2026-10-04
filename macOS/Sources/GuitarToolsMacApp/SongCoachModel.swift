import Combine
import Foundation
import GuitarToolsCore

/// Output-only click transport. Implementations must not request microphone access.
protocol SongCoachClicker: AnyObject {
    func start(
        config: MacMetronomeConfig,
        onBeat: @escaping @MainActor (MacBeatEvent) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    )
    func stop()
}

/// A replaceable wake-up source; elapsed time always comes from the injected clock.
protocol SongCoachTicker: AnyObject {
    func start(onTick: @escaping @MainActor () -> Void)
    func stop()
}

/// Adapts the existing output-only engine without changing it or opening an audio input.
final class SongCoachMetronomeClicker: SongCoachClicker {
    private var engine: MacMetronomeEngine?

    func start(
        config: MacMetronomeConfig,
        onBeat: @escaping @MainActor (MacBeatEvent) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) {
        if engine == nil { engine = MacMetronomeEngine() }
        engine?.start(
            configProvider: { config },
            onBeat: { event in Task { @MainActor in onBeat(event) } },
            onError: { error in Task { @MainActor in onError(error) } }
        )
    }

    func stop() { engine?.stop() }
    deinit { engine?.stop() }
}

final class SongCoachTimerTicker: SongCoachTicker {
    private var timer: Timer?

    func start(onTick: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in onTick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }
}

@MainActor
final class SongCoachModel: ObservableObject {
    enum Phase: Equatable {
        case ready, countIn, playing, paused, completed
    }

    let chart: ChordChart
    let plan: SongTransitionPlan
    let goalBPM: Int
    /// One source bar per chord (quarter-note click events in the source meter).
    let beatsPerChord: Int

    @Published private(set) var selectedID: String?
    @Published private(set) var bpm: Int
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var activeChordIndex = 0
    /// Zero-based source-bar beat, matching the native beat strip.
    @Published private(set) var beatInChord = 0
    @Published private(set) var countInRemaining: Int?
    @Published private(set) var secondsRemaining = 30.0
    @Published private(set) var feedbackMessage: String?
    @Published private(set) var soundError: String?
    @Published private(set) var progress: SongCoachProgress

    private let store: SongCoachProgressStore
    private let clicker: any SongCoachClicker
    private let clock: any AudioHostClock
    private let ticker: any SongCoachTicker
    private let initialBPM: Int
    private var generation: UInt64 = 0
    private var elapsed = 0.0
    private var playingSince: Double?
    private var practicePulses = 0
    private var rated = false
    private var countedRound = false

    init(
        chart: ChordChart,
        sourceBPM: Int,
        initialBeat: Double = 0,
        voicingSelections: [String: String] = [:],
        progressStore: SongCoachProgressStore = SongCoachProgressStore(),
        clicker: any SongCoachClicker = SongCoachMetronomeClicker(),
        clock: any AudioHostClock = SystemAudioHostClock(),
        ticker: any SongCoachTicker = SongCoachTimerTicker()
    ) {
        let builtPlan = SongTransitionPlan(chart: chart, voicingSelections: voicingSelections)
        let sourceGoal = Self.clampBPM(sourceBPM)
        let startingTempo = max(40, min(80, Int((Double(sourceGoal) * 0.55).rounded())))
        self.chart = chart
        plan = builtPlan
        goalBPM = sourceGoal
        initialBPM = startingTempo
        beatsPerChord = min(max(chart.beatsPerBar, 1), 32)
        store = progressStore
        self.clicker = clicker
        self.clock = clock
        self.ticker = ticker

        // An explicit viewer position wins over a saved pair. At the song's beginning,
        // restore the last valid pair, or choose the pair nearest that position.
        let beat = initialBeat.isFinite ? max(initialBeat, 0) : 0
        let savedID = progressStore.selectedTransitionID(chart: chart)
        let saved = builtPlan.transitions.first { $0.id == savedID }
        let nearest = builtPlan.transitions.min { left, right in
            let lhs = left.occurrenceBeats.map { abs($0 - beat) }.min() ?? .infinity
            let rhs = right.occurrenceBeats.map { abs($0 - beat) }.min() ?? .infinity
            return lhs < rhs
        }
        let selection = (beat == 0 ? saved ?? nearest : nearest)?.id
        selectedID = selection
        let restored = selection.flatMap {
            progressStore.progress(chart: chart, transitionID: $0)
        } ?? SongCoachProgress(bpm: startingTempo)
        progress = restored
        bpm = restored.bpm
    }

    deinit {
        clicker.stop()
        ticker.stop()
    }

    var selectedTransition: SongChordTransition? {
        plan.transitions.first { $0.id == selectedID }
    }

    var isActive: Bool { phase == .countIn || phase == .playing }

    /// A self-report is available only after some active practice, once per round.
    var canRate: Bool {
        !rated && selectedTransition != nil && currentElapsed > 0 &&
        (phase == .playing || phase == .paused || phase == .completed)
    }

    func setBPM(_ value: Int) {
        let newBPM = Self.clampBPM(value)
        guard newBPM != bpm else { return }
        let resume = isActive
        if resume { pause() }
        bpm = newBPM
        feedbackMessage = nil
        progress.bpm = newBPM
        persist()
        if resume && phase != .completed { start() }
    }

    func select(_ id: String) {
        guard id != selectedID, plan.transitions.contains(where: { $0.id == id }) else { return }
        stop()
        selectedID = id
        progress = store.progress(chart: chart, transitionID: id)
            ?? SongCoachProgress(bpm: initialBPM)
        bpm = progress.bpm
        feedbackMessage = nil
        soundError = nil
        persist()
    }

    func start() {
        guard !isActive, selectedTransition != nil else { return }
        if phase == .completed || rated { resetRound() }
        cancelTransport()
        // The engine always resumes with a fresh bar. Repeat a partially played
        // block, or prepare the next chord when its first pulse was already next.
        practicePulses = (practicePulses / beatsPerChord) * beatsPerChord
        activeChordIndex = (practicePulses / beatsPerChord) % 2
        beatInChord = 0
        soundError = nil
        feedbackMessage = nil
        phase = .countIn
        countInRemaining = beatsPerChord
        let token = generation
        let config = MacMetronomeConfig(
            bpm: bpm,
            beatsPerBar: beatsPerChord,
            beatUnit: [1, 2, 4, 8, 16].contains(chart.beatUnit) ? chart.beatUnit : 4,
            subdivision: .quarter,
            accents: (0..<beatsPerChord).map { $0 == 0 ? .accent : .normal },
            clickSound: .digital,
            countInBars: 1
        )
        clicker.start(
            config: config,
            onBeat: { [weak self] event in self?.handleBeat(event, token: token) },
            onError: { [weak self] error in self?.handleError(error, token: token) }
        )
    }

    func pause() {
        guard isActive else { return }
        sampleElapsed()
        guard phase != .completed else { return }
        cancelTransport()
        phase = .paused
    }

    /// Ends transport and resets this round. Queued beats/ticks cannot replay it.
    func stop() {
        cancelTransport()
        resetRound()
        phase = .ready
    }

    func rateComfortable() { rate(comfortable: true) }
    func rateDifficult() { rate(comfortable: false) }

    private func rate(comfortable: Bool) {
        guard canRate else { return }
        pause()
        countedRoundIfNeeded()
        rated = true
        if comfortable {
            if progress.comfortableRounds < Int.max { progress.comfortableRounds += 1 }
            // Respect an explicitly chosen faster tempo; positive feedback must
            // never unexpectedly slow the practice down.
            if bpm < goalBPM { bpm = min(goalBPM, bpm + 5) }
            feedbackMessage = "次は\(bpm) BPMで。自己チェックを目安に、無理なく練習しましょう。"
        } else {
            bpm = max(40, bpm - 10)
            feedbackMessage = "\(bpm) BPMに下げました。自己チェックを目安に、ゆっくり練習しましょう。"
        }
        progress.bpm = bpm
        persist()
    }

    private func handleBeat(_ event: MacBeatEvent, token: UInt64) {
        guard token == generation, isActive, event.isMainBeat else { return }
        if event.isCountIn {
            guard phase == .countIn else { return }
            beatInChord = min(max(event.beatInBar, 0), beatsPerChord - 1)
            countInRemaining = beatsPerChord - beatInChord
            return
        }
        if phase == .countIn {
            phase = .playing
            countInRemaining = nil
            playingSince = finiteNow
            ticker.start { [weak self] in
                guard let self, self.generation == token, self.phase == .playing else { return }
                self.sampleElapsed()
            }
        }
        sampleElapsed()
        guard phase == .playing else { return }
        activeChordIndex = (practicePulses / beatsPerChord) % 2
        beatInChord = practicePulses % beatsPerChord
        practicePulses = (practicePulses + 1) % (beatsPerChord * 2)
    }

    private func handleError(_ error: Error, token: UInt64) {
        guard token == generation, isActive else { return }
        sampleElapsed()
        cancelTransport()
        if phase != .completed { phase = elapsed > 0 ? .paused : .ready }
        soundError = error.localizedDescription
    }

    private var finiteNow: Double {
        let now = clock.nowSeconds()
        return now.isFinite ? now : playingSince ?? 0
    }

    private var currentElapsed: Double {
        min(30, elapsed + (playingSince.map { max(0, finiteNow - $0) } ?? 0))
    }

    private func sampleElapsed() {
        guard phase == .playing else { return }
        elapsed = currentElapsed
        playingSince = finiteNow
        secondsRemaining = max(0, 30 - elapsed)
        if elapsed >= 30 {
            cancelTransport()
            phase = .completed
            countedRoundIfNeeded()
            persist()
        }
    }

    private func countedRoundIfNeeded() {
        guard !countedRound else { return }
        countedRound = true
        if progress.totalRounds < Int.max { progress.totalRounds += 1 }
    }

    private func resetRound() {
        elapsed = 0
        playingSince = nil
        secondsRemaining = 30
        activeChordIndex = 0
        beatInChord = 0
        practicePulses = 0
        rated = false
        countedRound = false
    }

    private func cancelTransport() {
        generation &+= 1
        clicker.stop()
        ticker.stop()
        playingSince = nil
        countInRemaining = nil
    }

    private func persist() {
        guard let selectedID else { return }
        store.save(progress, chart: chart, transitionID: selectedID)
    }

    private static func clampBPM(_ value: Int) -> Int { min(max(value, 40), 300) }
}
