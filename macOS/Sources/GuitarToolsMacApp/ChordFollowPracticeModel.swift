import Combine
import Foundation
import GuitarToolsCore

@MainActor
final class ChordFollowPracticeModel:
    ObservableObject {

    @Published
    var query = ""

    @Published private(set)
    var searchResults:
        [ChordWikiSearchResult] = []

    @Published private(set)
    var isSearching = false

    @Published private(set)
    var isLoadingChart = false

    @Published private(set)
    var errorMessage: String?

    @Published private(set)
    var chart: ChordChart?

    @Published private(set)
    var timeline: ChordTimeline?

    @Published
    var bpm = 120

    @Published private(set)
    var currentSeconds = 0.0

    @Published private(set)
    var isPlaying = false

    @Published private(set)
    var attempts:
        [PracticeAttempt] = []

    @Published private(set)
    var lastAttempt:
        PracticeAttempt?

    @Published private(set)
    var pendingExpected:
        TimedChordEvent?

    @Published
    var inputLatencyCompensationMs =
        0.0

    @Published
    var onTimeToleranceMs =
        90.0

    @Published
    var autoScroll = true

    private let audio:
        AudioInputModel

    private let clock:
        any AudioHostClock

    private let sessionStore:
        PracticeSessionStore

    private let client =
        ChordWikiMacClient()

    private var timer: Timer?
    private var playbackStartHostSeconds =
        0.0

    private var claimedEventIDs =
        Set<Int>()

    private var pending:
        PendingAttempt?

    private var sessionStartedAt:
        Date?

    init(
        audio: AudioInputModel,
        clock:
            any AudioHostClock =
            SystemAudioHostClock(),
        sessionStore:
            PracticeSessionStore =
            PracticeSessionStore()
    ) {
        self.audio = audio
        self.clock = clock
        self.sessionStore =
            sessionStore

        audio.onOnset = {
            [weak self]
            onset in

            Task {
                @MainActor in
                self?.handleOnset(
                    onset
                )
            }
        }

        audio.onStableChord = {
            [weak self]
            chord,
            timestamp in

            Task {
                @MainActor in
                self?.handleStableChord(
                    chord,
                    timestamp:
                        timestamp
                )
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    var currentBeat: Double {
        guard bpm > 0 else {
            return 0
        }

        return currentSeconds *
            Double(bpm) /
            60
    }

    var currentEvent:
        TimedChordEvent? {
        timeline?.event(
            atBeat: currentBeat
        )
    }

    var durationSeconds: Double {
        guard
            let timeline,
            bpm > 0
        else {
            return 0
        }

        return timeline.seconds(
            forBeat:
                timeline.totalBeats,
            bpm: bpm
        )
    }

    var statistics:
        PracticeStatistics {
        ChordFollowEvaluator
            .statistics(
                attempts: attempts
            )
    }

    func search() {
        let trimmed =
            query.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            return
        }

        isSearching = true
        errorMessage = nil

        Task {
            do {
                let values =
                    try await client.search(
                        query: trimmed
                    )

                self.searchResults =
                    values
                self.isSearching =
                    false
            } catch {
                self.searchResults = []
                self.isSearching =
                    false
                self.errorMessage =
                    error.localizedDescription
            }
        }
    }

    func open(
        _ result:
            ChordWikiSearchResult
    ) {
        persistCurrentSession()
        pause()

        isLoadingChart = true
        errorMessage = nil

        Task {
            do {
                let loaded =
                    try await client
                        .loadChart(result)

                let built =
                    ChordTimelineBuilder
                        .build(
                            chart: loaded
                        )

                self.chart = loaded
                self.timeline = built
                self.bpm =
                    loaded.bpm ?? 120
                self.currentSeconds = 0
                self.attempts = []
                self.lastAttempt = nil
                self.claimedEventIDs = []
                self.pending = nil
                self.pendingExpected = nil
                self.sessionStartedAt =
                    nil
                self.isLoadingChart =
                    false
            } catch {
                self.isLoadingChart =
                    false
                self.errorMessage =
                    error.localizedDescription
            }
        }
    }

    func closeChart() {
        persistCurrentSession()
        pause()
        chart = nil
        timeline = nil
        currentSeconds = 0
        attempts = []
        lastAttempt = nil
        pending = nil
        pendingExpected = nil
        claimedEventIDs = []
        sessionStartedAt = nil
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard
            timeline != nil,
            durationSeconds > 0
        else {
            return
        }

        if currentSeconds >=
            durationSeconds {
            persistCurrentSession()
            currentSeconds = 0
            claimedEventIDs = []
            attempts = []
            lastAttempt = nil
            sessionStartedAt = nil
        }

        if !audio.isRunning {
            audio
                .requestPermissionAndStart()
        }

        if sessionStartedAt == nil {
            sessionStartedAt =
                Date()
        }

        playbackStartHostSeconds =
            clock.nowSeconds() -
            currentSeconds

        isPlaying = true
        installTimer()
    }

    func pause() {
        if isPlaying {
            updateClock()
        }

        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func resetSession() {
        persistCurrentSession()
        pause()
        currentSeconds = 0
        attempts = []
        lastAttempt = nil
        claimedEventIDs = []
        pending = nil
        pendingExpected = nil
        sessionStartedAt = nil
    }

    func seek(
        to seconds: Double
    ) {
        currentSeconds =
            min(
                max(
                    seconds,
                    0
                ),
                durationSeconds
            )

        if isPlaying {
            playbackStartHostSeconds =
                clock.nowSeconds() -
                currentSeconds
        }
    }

    private func installTimer() {
        timer?.invalidate()

        timer =
            Timer.scheduledTimer(
                withTimeInterval:
                    1.0 / 30.0,
                repeats: true
            ) {
                [weak self]
                _ in

                Task {
                    @MainActor in
                    self?.tick()
                }
            }
    }

    private func tick() {
        guard isPlaying else {
            return
        }

        updateClock()

        if currentSeconds >=
            durationSeconds {
            currentSeconds =
                durationSeconds
            pause()
        }

        if let pending,
           clock.nowSeconds() -
            pending.onsetTimestamp >
            0.8 {
            finalizePending(
                playedChord: nil
            )
        }
    }

    private func updateClock() {
        currentSeconds =
            min(
                max(
                    clock.nowSeconds() -
                    playbackStartHostSeconds,
                    0
                ),
                durationSeconds
            )
    }

    private func handleOnset(
        _ onset: AudioOnset
    ) {
        guard
            isPlaying,
            let timeline
        else {
            return
        }

        if pending != nil {
            return
        }

        let compensated =
            onset.timestampSeconds -
            inputLatencyCompensationMs /
            1_000

        let practiceTime =
            compensated -
            playbackStartHostSeconds

        let candidate =
            timeline.events
                .filter {
                    !claimedEventIDs
                        .contains(
                            $0.id
                        )
                }
                .map {
                    event in

                    (
                        event,
                        timeline.seconds(
                            forBeat:
                                event.startBeat,
                            bpm: bpm
                        )
                    )
                }
                .min {
                    abs(
                        $0.1 -
                            practiceTime
                    ) <
                    abs(
                        $1.1 -
                            practiceTime
                    )
                }

        guard
            let (
                event,
                expectedTime
            ) = candidate
        else {
            return
        }

        let errorMs =
            (
                practiceTime -
                expectedTime
            ) * 1_000

        let matchingWindowMs =
            max(
                260,
                min(
                    900,
                    event.durationBeats *
                        60_000 /
                        Double(bpm) *
                        0.5
                )
            )

        guard
            abs(errorMs) <=
                matchingWindowMs
        else {
            return
        }

        claimedEventIDs.insert(
            event.id
        )

        pending =
            PendingAttempt(
                event: event,
                timingErrorMs:
                    errorMs,
                onsetTimestamp:
                    onset.timestampSeconds
            )

        pendingExpected =
            event
    }

    private func handleStableChord(
        _ chord: String,
        timestamp: Double
    ) {
        guard let pending else {
            return
        }

        let elapsed =
            timestamp -
            pending.onsetTimestamp

        guard
            elapsed >= 0.06,
            elapsed <= 0.8
        else {
            return
        }

        finalizePending(
            playedChord: chord
        )
    }

    private func finalizePending(
        playedChord: String?
    ) {
        guard let pending else {
            return
        }

        let attempt =
            ChordFollowEvaluator
                .attempt(
                    event:
                        pending.event,
                    playedChord:
                        playedChord,
                    timingErrorMs:
                        pending
                            .timingErrorMs,
                    onTimeToleranceMs:
                        onTimeToleranceMs
                )

        attempts.append(attempt)
        lastAttempt = attempt

        self.pending = nil
        pendingExpected = nil
    }

    private func persistCurrentSession() {
        guard
            let chart,
            let sessionStartedAt,
            !attempts.isEmpty
        else {
            return
        }

        let session =
            PracticeSession(
                startedAt:
                    sessionStartedAt,
                endedAt: Date(),
                title: chart.title,
                artist: chart.artist,
                sourceIdentifier:
                    chart.sourceURL?
                        .absoluteString,
                bpm: bpm,
                beatsPerBar:
                    chart.beatsPerBar,
                onTimeToleranceMs:
                    onTimeToleranceMs,
                inputLatencyCompensationMs:
                    inputLatencyCompensationMs,
                attempts: attempts
            )

        Task {
            try? await sessionStore
                .save(session)
        }
    }

    private struct PendingAttempt {
        let event:
            TimedChordEvent
        let timingErrorMs:
            Double
        let onsetTimestamp:
            Double
    }
}
