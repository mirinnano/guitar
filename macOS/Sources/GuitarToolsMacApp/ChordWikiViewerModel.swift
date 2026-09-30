import Combine
import Foundation
import GuitarToolsCore

@MainActor
final class ChordWikiViewerModel:
    ObservableObject {

    @Published
    var query = ""

    @Published private(set)
    var results:
        [ChordWikiSearchResult] = []

    @Published private(set)
    var isSearching = false

    @Published private(set)
    var chart: ChordChart?

    @Published private(set)
    var timeline:
        ChordTimeline?

    @Published private(set)
    var isLoading = false

    @Published
    var bpm = 120

    @Published
    var autoScroll = true

    @Published
    var metronomeEnabled =
        false

    @Published
    var youtubeSyncEnabled =
        false

    @Published
    var calibrationMode =
        false

    @Published
    var youtubeOffsetMs:
        Int64 = 0

    @Published private(set)
    var currentBeat = 0.0

    @Published private(set)
    var isPlaying = false

    @Published private(set)
    var youtubePlaying =
        false

    @Published private(set)
    var youtubePositionMs:
        Int64 = 0

    @Published private(set)
    var youtubeDurationMs:
        Int64 = 0

    @Published private(set)
    var youtubePlaybackRate =
        1.0

    @Published private(set)
    var anchors:
        [ChordSyncAnchor] = []

    @Published private(set)
    var errorMessage: String?

    @Published private(set)
    var syncNotice: String?

    private let client =
        ChordWikiMacClient()

    private let store =
        ChordSyncStore()

    private let metronome =
        MacMetronomeEngine()

    private let clock:
        any AudioHostClock

    init(
        clock:
            any AudioHostClock =
            SystemAudioHostClock()
    ) {
        self.clock = clock
    }

    private var timer: Timer?

    private var internalStartBeat =
        0.0

    private var internalStartTime =
        0.0

    private var lastVideoSampleAt =
        0.0

    private var lastVideoPosition:
        Int64 = 0

    private var metronomeTask:
        Task<Void, Never>?

    var currentEvent:
        TimedChordEvent? {
        timeline?
            .event(
                atBeat:
                    currentBeat
            )
    }

    var syncStatus:
        ChordSyncStatus? {
        syncMap?
            .status(
                atBeat:
                    currentBeat
            )
    }

    private var syncMap:
        ChordSyncMap? {
        guard let timeline
        else {
            return nil
        }

        return ChordSyncMap(
            anchors: anchors,
            fallbackBPM: bpm,
            fallbackOffsetMs:
                youtubeOffsetMs,
            totalBeats:
                timeline.totalBeats
        )
    }

    func search() {
        let value =
            query.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !value.isEmpty
        else {
            return
        }

        isSearching = true
        errorMessage = nil

        Task {
            do {
                results =
                    try await client
                        .search(
                            query: value
                        )
                isSearching = false
            } catch {
                results = []
                isSearching = false
                errorMessage =
                    error.localizedDescription
            }
        }
    }

    func open(
        _ result:
            ChordWikiSearchResult
    ) {
        stop()
        isLoading = true
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

                chart = loaded
                timeline = built
                bpm =
                    min(
                        max(
                            loaded.bpm
                            ?? 120,
                            30
                        ),
                        300
                    )

                currentBeat = 0
                youtubePositionMs = 0
                youtubeDurationMs = 0
                youtubePlaybackRate = 1
                youtubePlaying = false
                youtubeSyncEnabled =
                    loaded
                        .youtubeVideoID !=
                    nil
                calibrationMode =
                    false
                anchors =
                    store.load(
                        chart: loaded
                    )
                    .filter {
                        $0.chartBeat >= 0 &&
                        $0.chartBeat <=
                            built.totalBeats
                    }

                isLoading = false
            } catch {
                isLoading = false
                errorMessage =
                    error.localizedDescription
            }
        }
    }

    func close() {
        stop()
        chart = nil
        timeline = nil
        currentBeat = 0
        anchors = []
        calibrationMode = false
        syncNotice = nil
    }

    func toggleInternalPlayback() {
        guard !youtubeSyncEnabled
        else {
            return
        }

        isPlaying
        ? stop()
        : startInternal()
    }

    func startInternal() {
        guard
            let timeline,
            timeline.totalBeats > 0
        else {
            return
        }

        if currentBeat >=
            timeline.totalBeats {
            currentBeat = 0
        }

        internalStartBeat =
            currentBeat

        internalStartTime =
            clock.nowSeconds()

        isPlaying = true
        installTimer()
        restartMetronome()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        metronomeTask?.cancel()
        metronomeTask = nil
        metronome.stop()
        isPlaying = false
    }

    func seek(
        beat: Double
    ) {
        guard let timeline
        else {
            return
        }

        currentBeat =
            min(
                max(
                    beat,
                    0
                ),
                timeline.totalBeats
            )

        if youtubeSyncEnabled {
            youtubePositionMs =
                syncMap?
                    .videoPositionMs(
                        forBeat:
                            currentBeat
                    )
                ?? 0
        } else if isPlaying {
            internalStartBeat =
                currentBeat
            internalStartTime =
                clock.nowSeconds()
        }

        if isPlaying {
            restartMetronome()
        }
    }

    func videoPosition(
        forBeat beat: Double
    ) -> Int64 {
        syncMap?
            .videoPositionMs(
                forBeat: beat
            )
        ?? 0
    }

    func setYouTubeOffset(
        _ value: Int64
    ) {
        youtubeOffsetMs =
            min(
                max(
                    value,
                    -30_000
                ),
                120_000
            )

        if youtubeSyncEnabled {
            currentBeat =
                syncMap?
                    .beat(
                        forVideoPositionMs:
                            estimatedYouTubePosition()
                    )
                ?? currentBeat
        }
    }

    func setYouTubeSync(
        _ enabled: Bool
    ) {
        guard
            !enabled ||
            chart?
                .youtubeVideoID !=
                nil
        else {
            return
        }

        if enabled {
            stopInternalTimerOnly()
            youtubeSyncEnabled = true
            currentBeat =
                syncMap?
                    .beat(
                        forVideoPositionMs:
                            estimatedYouTubePosition()
                    )
                ?? 0
            isPlaying =
                youtubePlaying
        } else {
            youtubeSyncEnabled =
                false
            calibrationMode =
                false
            stop()
        }
    }

    func onYouTubeProgress(
        positionMs: Int64,
        durationMs: Int64,
        playing: Bool,
        rate: Double
    ) {
        let wasPlaying =
            youtubePlaying

        lastVideoSampleAt =
            clock.nowSeconds()

        lastVideoPosition =
            max(
                positionMs,
                0
            )

        youtubePositionMs =
            max(
                positionMs,
                0
            )

        youtubeDurationMs =
            max(
                durationMs,
                0
            )

        youtubePlaybackRate =
            rate > 0
            ? rate
            : 1

        youtubePlaying =
            playing

        if youtubeSyncEnabled {
            currentBeat =
                syncMap?
                    .beat(
                        forVideoPositionMs:
                            youtubePositionMs
                    )
                ?? 0

            isPlaying =
                playing

            if playing {
                installTimer()
            } else {
                timer?.invalidate()
                timer = nil
            }
        }

        if metronomeEnabled &&
            youtubeSyncEnabled &&
            (
                wasPlaying !=
                playing
            ) {
            if playing {
                restartMetronome()
            } else {
                metronome.stop()
            }
        }
    }

    func setCalibrationMode(
        _ enabled: Bool
    ) {
        calibrationMode =
            enabled

        if enabled {
            setYouTubeSync(true)
            autoScroll = false
            syncNotice =
                "動画をコード開始位置に合わせ、譜面上のコードをクリックしてください"
        }
    }

    func addAnchor(
        event:
            TimedChordEvent
    ) {
        guard
            let chart,
            chart.youtubeVideoID !=
                nil
        else {
            return
        }

        let candidate =
            ChordSyncAnchor(
                chartBeat:
                    event.startBeat,
                videoPositionMs:
                    estimatedYouTubePosition(),
                symbol:
                    event.symbol,
                lineIndex:
                    event.lineIndex,
                segmentIndex:
                    event.segmentIndex
            )

        guard
            ChordSyncMap
                .canInsert(
                    anchors:
                        anchors,
                    candidate:
                        candidate
                )
        else {
            syncNotice =
                "前後のアンカー時刻が逆転します。動画位置を確認してください。"
            return
        }

        anchors =
            ChordSyncMap.upsert(
                anchors: anchors,
                candidate:
                    candidate
            )

        store.save(
            anchors,
            chart: chart
        )

        currentBeat =
            event.startBeat

        switch anchors.count {
        case 1:
            syncNotice =
                "1点固定: 開始オフセットを補正"
        case 2:
            syncNotice =
                "2点固定: 曲全体のテンポ差を補正"
        default:
            syncNotice =
                "\(anchors.count)点固定: 区間ごとのテンポ差を補正"
        }

        if isPlaying {
            restartMetronome()
        }
    }

    func nudgeAnchor(
        _ anchor:
            ChordSyncAnchor,
        deltaMs: Int64
    ) {
        guard let chart
        else {
            return
        }

        let candidate =
            ChordSyncAnchor(
                chartBeat:
                    anchor.chartBeat,
                videoPositionMs:
                    max(
                        anchor
                            .videoPositionMs +
                        deltaMs,
                        0
                    ),
                symbol:
                    anchor.symbol,
                lineIndex:
                    anchor.lineIndex,
                segmentIndex:
                    anchor.segmentIndex
            )

        guard
            ChordSyncMap
                .canInsert(
                    anchors:
                        anchors,
                    candidate:
                        candidate
                )
        else {
            return
        }

        anchors =
            ChordSyncMap.upsert(
                anchors: anchors,
                candidate:
                    candidate
            )

        store.save(
            anchors,
            chart: chart
        )
    }

    func removeAnchor(
        _ anchor:
            ChordSyncAnchor
    ) {
        guard let chart
        else {
            return
        }

        anchors.removeAll {
            abs(
                $0.chartBeat -
                anchor.chartBeat
            ) <
            0.0001
        }

        if anchors.isEmpty {
            store.clear(
                chart: chart
            )
        } else {
            store.save(
                anchors,
                chart: chart
            )
        }
    }

    func clearAnchors() {
        guard let chart
        else {
            return
        }

        anchors = []
        store.clear(
            chart: chart
        )
        syncNotice =
            "BPM + 開始オフセット同期へ戻りました"
    }

    func setMetronome(
        _ enabled: Bool
    ) {
        metronomeEnabled =
            enabled

        if enabled &&
            isPlaying {
            restartMetronome()
        } else {
            metronome.stop()
        }
    }

    private func installTimer() {
        timer?.invalidate()

        timer =
            Timer.scheduledTimer(
                withTimeInterval:
                    1.0 / 30,
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
        guard isPlaying
        else {
            return
        }

        if youtubeSyncEnabled {
            youtubePositionMs =
                estimatedYouTubePosition()

            currentBeat =
                syncMap?
                    .beat(
                        forVideoPositionMs:
                            youtubePositionMs
                    )
                ?? 0

            return
        }

        guard let timeline
        else {
            return
        }

        let elapsed =
            clock.nowSeconds() -
            internalStartTime

        currentBeat =
            internalStartBeat +
            elapsed *
            Double(bpm) /
            60

        if currentBeat >=
            timeline.totalBeats {
            currentBeat =
                timeline.totalBeats
            stop()
        }
    }

    private func stopInternalTimerOnly() {
        timer?.invalidate()
        timer = nil
        metronome.stop()
        isPlaying = false
    }

    private func estimatedYouTubePosition()
        -> Int64 {

        guard youtubePlaying
        else {
            return youtubePositionMs
        }

        let elapsed =
            clock.nowSeconds() -
            lastVideoSampleAt

        let estimate =
            Double(
                lastVideoPosition
            ) +
            elapsed *
            1_000 *
            youtubePlaybackRate

        return Int64(
            max(
                estimate.rounded(),
                0
            )
        )
    }

    private func restartMetronome() {
        metronomeTask?.cancel()
        metronome.stop()

        guard
            metronomeEnabled,
            isPlaying
        else {
            return
        }

        let localBPM =
            youtubeSyncEnabled
            ? syncMap?
                .localBPM(
                    atBeat:
                        currentBeat
                )
                ?? Double(bpm)
            : Double(bpm)

        let effective =
            max(
                localBPM *
                (
                    youtubeSyncEnabled
                    ? youtubePlaybackRate
                    : 1
                ),
                30
            )

        let fraction =
            currentBeat -
            floor(currentBeat)

        let delay =
            fraction < 0.02
            ? 0
            : (
                1 -
                fraction
            ) *
            60 /
            effective

        let startingBeat =
            Int(
                floor(
                    currentBeat +
                    (
                        delay > 0
                        ? 1
                        : 0
                    )
                )
            )

        metronomeTask =
            Task {
                [weak self] in

                if delay > 0 {
                    try? await Task
                        .sleep(
                            for:
                                .seconds(
                                    delay
                                )
                        )
                }

                guard
                    !Task.isCancelled,
                    let self,
                    self.isPlaying,
                    self.metronomeEnabled
                else {
                    return
                }

                self.metronome
                    .start(
                        startingBeat:
                            startingBeat,
                        configProvider: {
                            [weak self] in

                            guard let self
                            else {
                                return MacMetronomeConfig()
                            }

                            let local =
                                self
                                    .youtubeSyncEnabled
                                ? self.syncMap?
                                    .localBPM(
                                        atBeat:
                                            self.currentBeat
                                    )
                                    ?? Double(
                                        self.bpm
                                    )
                                : Double(
                                    self.bpm
                                )

                            return MacMetronomeConfig(
                                bpm:
                                    min(
                                        max(
                                            Int(
                                                (
                                                    local *
                                                    (
                                                        self.youtubeSyncEnabled
                                                        ? self.youtubePlaybackRate
                                                        : 1
                                                    )
                                                )
                                                .rounded()
                                            ),
                                            30
                                        ),
                                        300
                                    ),
                                beatsPerBar:
                                    self.chart?
                                        .beatsPerBar
                                    ?? 4,
                                beatUnit:
                                    self.chart?
                                        .beatUnit
                                    ?? 4,
                                subdivision:
                                    .quarter,
                                accents:
                                    Array(
                                        0..<(
                                            self.chart?
                                                .beatsPerBar
                                            ?? 4
                                        )
                                    )
                                    .map {
                                        $0 == 0
                                        ? .accent
                                        : .normal
                                    }
                            )
                        },
                        onBeat: {
                            _ in
                        }
                    )
            }
    }
}
