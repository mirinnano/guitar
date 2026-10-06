import Combine
import Foundation
import GuitarToolsCore

@MainActor
final class ChordWikiViewerModel:
    ObservableObject {

    @Published
    var query = ""

    @Published private(set)
    var lastSearchQuery: String?

    @Published private(set)
    var results:
        [ChordWikiSearchResult] = []

    @Published private(set) var recentCharts: [ChordWikiSearchResult] = []
    private let recentStore: RecentChartsStore?
    private let timingDefaults: UserDefaults?

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
    var bpm = 120 {
        didSet {
            guard bpm != oldValue, let timeline, isPlaying else { return }
            if youtubeSyncEnabled {
                // Without anchors, editing BPM should change the pace from here,
                // not reinterpret all audio already played at the new tempo.
                if anchors.isEmpty {
                    youtubeOffsetMs = estimatedYouTubePosition() - timeline.milliseconds(forBeat: currentBeat, bpm: bpm)
                }
            } else {
                let now = clock.nowSeconds()
                let oldSeconds = timeline.seconds(forBeat: internalStartBeat, bpm: oldValue)
                    + max(now - internalStartTime, 0) * internalPlaybackRate
                currentBeat = timeline.beat(forSeconds: oldSeconds, bpm: oldValue)
                internalStartBeat = currentBeat
                internalStartTime = now
            }
            scrollRevision &+= 1
            restartMetronome()
        }
    }

    @Published private(set) var unmarkedBarsPerLine: Int?
    @Published private(set) var scrollRevision: UInt64 = 0

    var currentLine: TimedChartLine? { timeline?.line(atBeat: currentBeat) }

    var playbackBPM: Double {
        if youtubeSyncEnabled { return syncMap?.localBPM(atBeat: currentBeat) ?? Double(bpm) }
        return timeline?.tempoMap(bpm: bpm).bpm(atBeat: currentBeat) ?? Double(bpm)
    }

    func secondsUntilNextLine() -> Double {
        guard let line = currentLine, let timeline else { return 0 }
        let end = line.startBeat + line.durationBeats
        let duration: Double
        if youtubeSyncEnabled {
            duration = Double(videoPosition(forBeat: end) - videoPosition(forBeat: currentBeat)) / 1_000
        } else {
            duration = timeline.seconds(forBeat: end, bpm: bpm) - timeline.seconds(forBeat: currentBeat, bpm: bpm)
        }
        return max(duration / (youtubeSyncEnabled ? youtubePlaybackRate : internalPlaybackRate), 0)
    }

    @Published
    var autoScroll = true

    @Published var countInEnabled = true
    @Published private(set) var countInRemaining: Int?
    @Published private(set) var internalPlaybackRate = 1.0
    @Published private(set) var practiceLoop: ChordPracticeLoop?
    @Published private(set) var loopEnabled = false
    @Published private(set) var loopRestartRevision: UInt64 = 0

    private var countInTask: Task<Void, Never>?
    private var countInStartBeat: Double?
    private var loopRestartPending = false

    @Published
    var metronomeEnabled =
        false

    @Published private(set)
    var youtubeVideoID: String?

    @Published private(set)
    var musicMessage: String?

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

    private let client:
        any ChordWikiClientProtocol

    private let store =
        ChordSyncStore()

    private let metronome =
        MacMetronomeEngine()

    private let clock:
        any AudioHostClock

    private var searchRequestID:
        UInt64 = 0

    private var chartRequestID:
        UInt64 = 0

    init(
        client:
            any ChordWikiClientProtocol =
            ChordChartMacClient(),
        clock:
            any AudioHostClock =
            SystemAudioHostClock(),
        recentStore: RecentChartsStore? = nil,
        timingDefaults: UserDefaults? = nil
    ) {
        self.client = client
        self.clock = clock
        self.recentStore = recentStore
        self.timingDefaults = timingDefaults
        recentCharts = recentStore?.entries ?? []
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
                timeline.totalBeats,
            tempoMap: timeline.tempoMap(bpm: bpm)
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

        searchRequestID &+= 1
        let requestID = searchRequestID

        close()
        lastSearchQuery = value
        results = []
        isSearching = true
        errorMessage = nil

        Task {
            do {
                let values =
                    try await client
                        .search(
                            query: value
                        )

                guard requestID ==
                    self.searchRequestID
                else {
                    return
                }

                self.results = values
                self.isSearching = false
            } catch {
                guard requestID ==
                    self.searchRequestID
                else {
                    return
                }

                self.results = []
                self.isSearching = false
                self.errorMessage =
                    error.localizedDescription
            }
        }
    }

    func open(
        _ result:
            ChordWikiSearchResult
    ) {
        chartRequestID &+= 1
        let requestID = chartRequestID

        stop()
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loaded =
                    try await client
                        .loadChart(result)

                let savedBars = timingDefaults?.object(forKey: timingKey(loaded)) as? Int
                let bars = savedBars.flatMap { (1...16).contains($0) ? $0 : nil }
                let built =
                    ChordTimelineBuilder
                        .build(
                            chart: loaded,
                            unmarkedBarsPerLine: bars
                        )

                guard requestID ==
                    self.chartRequestID
                else {
                    return
                }

                chart = loaded
                unmarkedBarsPerLine = bars
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
                youtubeOffsetMs = 0
                youtubeVideoID = loaded.youtubeVideoID
                musicMessage = nil
                youtubeSyncEnabled = youtubeVideoID != nil
                internalPlaybackRate = 1
                practiceLoop = ChordPracticeLoop.bars(startingAt: 0, timeline: built)
                loopEnabled = false
                loopRestartPending = false
                calibrationMode =
                    false
                anchors = retimedAnchors(store.load(chart: loaded), timeline: built)

                isLoading = false
                // ChordWiki uses the search title as the page lookup key;
                // the title inside the chart can be different.
                recentStore?.record(result)
                recentCharts = recentStore?.entries ?? []
            } catch {
                guard requestID ==
                    self.chartRequestID
                else {
                    return
                }

                isLoading = false
                errorMessage =
                    error.localizedDescription
            }
        }
    }

    func close() {
        chartRequestID &+= 1
        stop()
        isLoading = false
        chart = nil
        timeline = nil
        youtubeVideoID = nil
        youtubeSyncEnabled = false
        youtubePlaying = false
        musicMessage = nil
        currentBeat = 0
        anchors = []
        calibrationMode = false
        syncNotice = nil
        practiceLoop = nil
        loopEnabled = false
    }

    func removeRecentChart(_ result: ChordWikiSearchResult) {
        recentStore?.remove(result)
        recentCharts = recentStore?.entries ?? []
    }

    func setUnmarkedBarsPerLine(_ bars: Int?) {
        guard let chart, let previous = timeline else { return }
        let oldLine = currentLine
        let fraction = oldLine.map { (currentBeat - $0.startBeat) / $0.durationBeats } ?? 0
        unmarkedBarsPerLine = bars.map { min(max($0, 1), 16) }
        if let unmarkedBarsPerLine {
            timingDefaults?.set(unmarkedBarsPerLine, forKey: timingKey(chart))
        } else {
            timingDefaults?.removeObject(forKey: timingKey(chart))
        }
        let rebuilt = ChordTimelineBuilder.build(chart: chart, unmarkedBarsPerLine: unmarkedBarsPerLine)
        timeline = rebuilt
        anchors = retimedAnchors(anchors, timeline: rebuilt)
        if let oldLine, let newLine = rebuilt.lineTimings.first(where: { $0.lineIndex == oldLine.lineIndex }) {
            currentBeat = newLine.startBeat + fraction * newLine.durationBeats
        } else {
            currentBeat = min(currentBeat, rebuilt.totalBeats)
        }
        if previous.totalBeats != rebuilt.totalBeats {
            practiceLoop = ChordPracticeLoop.bars(startingAt: currentBeat, timeline: rebuilt)
            loopEnabled = false
        }
        internalStartBeat = currentBeat
        internalStartTime = clock.nowSeconds()
        if youtubeSyncEnabled {
            if anchors.isEmpty {
                youtubeOffsetMs = estimatedYouTubePosition() - rebuilt.milliseconds(forBeat: currentBeat, bpm: bpm)
            } else {
                currentBeat = syncMap?.beat(forVideoPositionMs: estimatedYouTubePosition()) ?? currentBeat
            }
        }
        scrollRevision &+= 1
        if isPlaying { restartMetronome() }
    }

    private func retimedAnchors(_ values: [ChordSyncAnchor], timeline: ChordTimeline) -> [ChordSyncAnchor] {
        values.compactMap { anchor in
            guard let event = timeline.events.first(where: {
                $0.lineIndex == anchor.lineIndex && $0.segmentIndex == anchor.segmentIndex && $0.symbol == anchor.symbol
            }) else { return nil }
            return ChordSyncAnchor(chartBeat: event.startBeat, videoPositionMs: anchor.videoPositionMs,
                                   symbol: anchor.symbol, lineIndex: anchor.lineIndex, segmentIndex: anchor.segmentIndex)
        }
    }

    private func timingKey(_ chart: ChordChart) -> String {
        "guitar-tools.chart-bars.v1:" + (chart.sourceURL?.absoluteString ?? chart.sourceTitle)
    }

    func setInternalPlaybackRate(_ rate: Double) {
        guard [0.5, 0.75, 1.0].contains(rate) else { return }
        internalStartBeat = currentBeat
        internalStartTime = clock.nowSeconds()
        internalPlaybackRate = rate
        scrollRevision &+= 1
        if isPlaying { restartMetronome() }
    }

    func setLoopEnabled(_ enabled: Bool) {
        loopEnabled = enabled && practiceLoop != nil
        loopRestartPending = false
        if loopEnabled, youtubeVideoID != nil { setYouTubeSync(true) }
    }

    func useFourBarLoop() {
        guard let timeline else { return }
        practiceLoop = ChordPracticeLoop.bars(startingAt: currentBeat, timeline: timeline)
        setLoopEnabled(true)
    }

    /// Returns a focused pair drill to its real position in the source song, paused.
    func prepareTransitionLoop(startBeat: Double, endBeat: Double) {
        guard let timeline,
              let range = ChordPracticeLoop(startBeat: startBeat, endBeat: endBeat, totalBeats: timeline.totalBeats)
        else { return }
        stop()
        practiceLoop = range
        setLoopEnabled(true)
        seek(beat: range.startBeat)
    }

    func setLoopStart() {
        guard let timeline else { return }
        let end = max(practiceLoop?.endBeat ?? 0, currentBeat + Double(timeline.beatsPerBar))
        practiceLoop = ChordPracticeLoop(startBeat: currentBeat, endBeat: end, totalBeats: timeline.totalBeats)
        if practiceLoop == nil { loopEnabled = false }
        loopRestartPending = false
    }

    func setLoopEnd() {
        guard let timeline else { return }
        if let range = ChordPracticeLoop(
            startBeat: practiceLoop?.startBeat ?? 0,
            endBeat: currentBeat,
            totalBeats: timeline.totalBeats
        ) {
            practiceLoop = range
            loopRestartPending = false
        }
    }

    func preparePlayback() {
        if loopEnabled, let range = practiceLoop, !range.contains(currentBeat) {
            seek(beat: range.startBeat)
        } else if let timeline, currentBeat >= timeline.totalBeats {
            seek(beat: 0)
        }
    }

    func beginPlayback(afterCountIn completion: @escaping () -> Void) {
        preparePlayback()
        guard countInEnabled, let chart else {
            completion()
            return
        }
        stop()
        let startBeat = currentBeat
        countInStartBeat = startBeat
        let beats = max(chart.beatsPerBar, 1)
        let rate = youtubeVideoID != nil ? youtubePlaybackRate : internalPlaybackRate
        let tempo = min(max(Int((playbackBPM * rate).rounded()), 30), 300)
        let config = MacMetronomeConfig(bpm: tempo, beatsPerBar: beats)
        metronome.start(configProvider: { config }, onBeat: { _ in })
        countInTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: beats, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                self.countInRemaining = remaining
                do {
                    try await Task.sleep(for: .seconds(60.0 / Double(tempo)))
                } catch { return }
            }
            guard !Task.isCancelled else { return }
            self.metronome.stop()
            self.countInRemaining = nil
            self.countInTask = nil
            self.countInStartBeat = nil
            // Resume at the prepared target, not a paused video's stale sample.
            self.seek(beat: startBeat)
            completion()
        }
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
        countInTask?.cancel()
        countInTask = nil
        countInRemaining = nil
        countInStartBeat = nil
        loopRestartPending = false
        youtubePlaying = false
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

        loopRestartPending = false
        scrollRevision &+= 1
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

    func attachMusicURL(_ url: String) {
        guard chart != nil else { return }
        guard let videoID = YouTubeLink.videoID(in: url) else {
            musicMessage = "有効なYouTubeの動画URLを貼り付けてください。"
            return
        }

        stop()
        youtubeVideoID = videoID
        youtubePlaying = false
        youtubePositionMs = 0
        youtubeDurationMs = 0
        youtubePlaybackRate = 1
        youtubeOffsetMs = 0
        currentBeat = 0
        loopEnabled = false
        anchors = []
        calibrationMode = false
        musicMessage = nil
        youtubeSyncEnabled = true
    }

    func musicUnavailable() {
        musicMessage = "この動画はアプリ内で再生できません。YouTubeで開くか、別の動画URLを指定してください。"
        youtubePlaying = false
        setYouTubeSync(false)
    }

    func setYouTubeSync(
        _ enabled: Bool
    ) {
        guard
            !enabled ||
            youtubeVideoID != nil
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

        let position = max(positionMs, 0)
        let duration = max(durationMs, 0)
        let playbackRate = rate > 0 ? rate : 1
        lastVideoPosition = position

        // Paused players still report at 10 Hz. Do not invalidate the chart
        // and its diagrams when the published state has not changed.
        if youtubePositionMs != position { youtubePositionMs = position }
        if youtubeDurationMs != duration { youtubeDurationMs = duration }
        if youtubePlaybackRate != playbackRate { youtubePlaybackRate = playbackRate }
        if youtubePlaying != playing { youtubePlaying = playing }

        // Keep receiving player metadata, but freeze the prepared chart target
        // until count-in completes (or stop cancels it).
        guard countInStartBeat == nil else { return }

        if youtubeSyncEnabled {
            let beat = syncMap?.beat(forVideoPositionMs: position) ?? 0
            if currentBeat != beat { currentBeat = beat }
            if isPlaying != playing { isPlaying = playing }

            if loopRestartPending, let range = practiceLoop, range.contains(currentBeat) {
                loopRestartPending = false
            }
            if playing || (wasPlaying && loopEnabled && currentBeat >= (practiceLoop?.endBeat ?? .infinity)) {
                applyVideoLoopIfNeeded()
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
            youtubeVideoID != nil
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

            applyVideoLoopIfNeeded()
            return
        }

        guard let timeline
        else {
            return
        }

        let elapsed =
            clock.nowSeconds() -
            internalStartTime

        let startSeconds = timeline.seconds(forBeat: internalStartBeat, bpm: bpm)
        currentBeat = timeline.beat(forSeconds: startSeconds + max(elapsed, 0) * internalPlaybackRate, bpm: bpm)

        if loopEnabled, let range = practiceLoop, currentBeat >= range.endBeat {
            currentBeat = range.wrappedBeat(currentBeat)
            internalStartBeat = currentBeat
            internalStartTime = clock.nowSeconds()
            restartMetronome()
        }

        if currentBeat >=
            timeline.totalBeats {
            currentBeat =
                timeline.totalBeats
            stop()
        }
    }

    private func applyVideoLoopIfNeeded() {
        guard loopEnabled, let range = practiceLoop,
              currentBeat >= range.endBeat, !loopRestartPending else { return }
        loopRestartPending = true
        currentBeat = range.startBeat
        youtubePositionMs = videoPosition(forBeat: range.startBeat)
        lastVideoPosition = youtubePositionMs
        lastVideoSampleAt = clock.nowSeconds()
        youtubePlaying = true
        isPlaying = true
        loopRestartRevision &+= 1
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
            : playbackBPM

        let effective =
            max(
                localBPM *
                (
                    youtubeSyncEnabled
                    ? youtubePlaybackRate
                    : internalPlaybackRate
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
                                : self.playbackBPM

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
                                                        : self.internalPlaybackRate
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
