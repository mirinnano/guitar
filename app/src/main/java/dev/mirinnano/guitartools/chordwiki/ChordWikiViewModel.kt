package dev.mirinnano.guitartools.chordwiki

import android.os.SystemClock
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.mirinnano.guitartools.audio.BeatAccent
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomeEngine
import dev.mirinnano.guitartools.audio.MetronomePlayer
import dev.mirinnano.guitartools.audio.MetronomeSubdivision
import kotlin.math.abs
import kotlin.math.floor
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

enum class ChordWikiPlaybackSource {
    INTERNAL,
    YOUTUBE
}

data class ChordWikiUiState(
    val query: String = "",
    val results: List<ChordWikiSearchResult> =
        emptyList(),
    val selectedSong: ChordWikiSong? = null,
    val timeline: ChordTimeline? = null,
    val isSearching: Boolean = false,
    val isLoadingSong: Boolean = false,
    val hasSearched: Boolean = false,
    val error: String? = null,
    val syncNotice: String? = null,
    val bpm: Int = 120,
    val beatsPerBar: Int = 4,
    val beatUnit: Int = 4,
    val currentBeat: Float = 0f,
    val isPlaying: Boolean = false,
    val playbackSource:
        ChordWikiPlaybackSource =
        ChordWikiPlaybackSource.INTERNAL,
    val autoScroll: Boolean = true,
    val metronomeEnabled: Boolean = false,
    val youtubeSyncEnabled: Boolean = false,
    val youtubePositionMs: Long = 0L,
    val youtubeDurationMs: Long = 0L,
    val youtubePlaying: Boolean = false,
    val youtubePlaybackRate: Float = 1f,
    val youtubeOffsetMs: Long = 0L,
    val calibrationMode: Boolean = false,
    val syncAnchors:
        List<ChordSyncAnchor> =
        emptyList()
) {
    val syncPrecision: ChordSyncPrecision
        get() =
            when (syncAnchors.size) {
                0 ->
                    ChordSyncPrecision.BPM_ONLY
                1 ->
                    ChordSyncPrecision.OFFSET_LOCKED
                2 ->
                    ChordSyncPrecision.GLOBAL_WARP
                else ->
                    ChordSyncPrecision.PIECEWISE_WARP
            }
}

class ChordWikiViewModel(
    private val client: ChordWikiClient =
        ChordWikiClient(),
    private val metronome: MetronomePlayer =
        MetronomeEngine(),
    private val syncStore:
        ChordSyncStore? = null,
    private val nowMs: () -> Long = {
        SystemClock.elapsedRealtime()
    }
) : ViewModel() {

    private val _uiState =
        MutableStateFlow(ChordWikiUiState())

    val uiState: StateFlow<ChordWikiUiState> =
        _uiState.asStateFlow()

    private var searchJob: Job? = null
    private var loadJob: Job? = null
    private var transportJob: Job? = null
    private var youtubeTickerJob: Job? = null
    private var metronomeStartJob: Job? = null

    private var transportStartBeat = 0f
    private var transportStartAtMs = 0L

    private var lastYoutubePositionMs:
        Long? = null
    private var lastYoutubeSampleAtMs:
        Long? = null
    private var lastYoutubePlaybackRate =
        1f

    fun setQuery(
        value: String
    ) {
        _uiState.update {
            it.copy(query = value)
        }
    }

    fun search() {
        val query =
            _uiState.value.query.trim()

        if (query.isEmpty()) {
            return
        }

        searchJob?.cancel()
        searchJob =
            viewModelScope.launch {
                _uiState.update {
                    it.copy(
                        isSearching = true,
                        hasSearched = true,
                        error = null
                    )
                }

                runCatching {
                    client.search(query)
                }.onSuccess { results ->
                    _uiState.update {
                        it.copy(
                            results = results,
                            isSearching = false,
                            error = null
                        )
                    }
                }.onFailure { error ->
                    _uiState.update {
                        it.copy(
                            results = emptyList(),
                            isSearching = false,
                            error =
                                error.message
                                    ?: "ChordWikiの検索に失敗しました"
                        )
                    }
                }
            }
    }

    fun openSong(
        result: ChordWikiSearchResult
    ) {
        loadJob?.cancel()
        loadJob =
            viewModelScope.launch {
                stopTransport()
                resetYoutubeSampling()

                _uiState.update {
                    it.copy(
                        isLoadingSong = true,
                        error = null,
                        syncNotice = null
                    )
                }

                runCatching {
                    client.loadSong(result)
                }.onSuccess { song ->
                    val beatsPerBar =
                        song.beatsPerBar
                            ?.coerceIn(1, 12)
                            ?: 4

                    val beatUnit =
                        song.beatUnit
                            ?.takeIf {
                                it in
                                    setOf(
                                        2,
                                        4,
                                        8,
                                        16
                                    )
                            }
                            ?: 4

                    val timeline =
                        ChordTimelineBuilder.build(
                            song = song,
                            beatsPerBar =
                                beatsPerBar
                        )

                    val restoredAnchors =
                        sanitizeStoredAnchors(
                            syncStore
                                ?.load(song)
                                .orEmpty(),
                            timeline
                        )

                    _uiState.update {
                        it.copy(
                            selectedSong = song,
                            timeline = timeline,
                            isLoadingSong = false,
                            error = null,
                            syncNotice = null,
                            bpm =
                                (
                                    song.bpm ?: 120
                                    ).coerceIn(
                                    MetronomeConfig.MIN_BPM,
                                    MetronomeConfig.MAX_BPM
                                ),
                            beatsPerBar =
                                beatsPerBar,
                            beatUnit = beatUnit,
                            currentBeat = 0f,
                            isPlaying = false,
                            playbackSource =
                                ChordWikiPlaybackSource.INTERNAL,
                            youtubeSyncEnabled =
                                song.youtubeVideoId != null,
                            youtubePositionMs = 0L,
                            youtubeDurationMs = 0L,
                            youtubePlaying = false,
                            youtubePlaybackRate = 1f,
                            youtubeOffsetMs = 0L,
                            calibrationMode = false,
                            syncAnchors =
                                restoredAnchors
                        )
                    }
                }.onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoadingSong = false,
                            error =
                                error.message
                                    ?: "ChordWikiの譜面を取得できませんでした"
                        )
                    }
                }
            }
    }

    fun closeSong() {
        loadJob?.cancel()
        stopTransport()
        resetYoutubeSampling()

        _uiState.update {
            it.copy(
                selectedSong = null,
                timeline = null,
                isLoadingSong = false,
                error = null,
                syncNotice = null,
                currentBeat = 0f,
                isPlaying = false,
                youtubeSyncEnabled = false,
                youtubePositionMs = 0L,
                youtubeDurationMs = 0L,
                youtubePlaying = false,
                youtubePlaybackRate = 1f,
                calibrationMode = false,
                syncAnchors =
                    emptyList()
            )
        }
    }

    fun setBpm(
        value: Int
    ) {
        val bpm =
            value.coerceIn(
                MetronomeConfig.MIN_BPM,
                MetronomeConfig.MAX_BPM
            )

        if (
            _uiState.value.isPlaying &&
            _uiState.value.playbackSource ==
                ChordWikiPlaybackSource.INTERNAL
        ) {
            reanchorInternalTransport()
        }

        _uiState.update { state ->
            val withBpm =
                state.copy(bpm = bpm)

            withBpm.copy(
                currentBeat =
                    if (
                        withBpm.youtubeSyncEnabled
                    ) {
                        youtubeBeatForPosition(
                            estimatedYoutubePositionMs(
                                withBpm
                            ),
                            withBpm
                        )
                    } else {
                        withBpm.currentBeat
                    }
            )
        }

        if (_uiState.value.isPlaying) {
            restartMetronomeAligned()
        }
    }

    fun setMeter(
        beatsPerBar: Int,
        beatUnit: Int
    ) {
        val state = _uiState.value
        val song =
            state.selectedSong
                ?: return

        val safeBeats =
            beatsPerBar.coerceIn(1, 12)
        val safeUnit =
            beatUnit.takeIf {
                it in setOf(2, 4, 8, 16)
            } ?: 4

        val timeline =
            ChordTimelineBuilder.build(
                song = song,
                beatsPerBar = safeBeats
            )

        val current =
            state.currentBeat.coerceIn(
                0f,
                timeline.totalBeats
            )

        syncStore?.clear(song)

        _uiState.update {
            it.copy(
                beatsPerBar = safeBeats,
                beatUnit = safeUnit,
                timeline = timeline,
                currentBeat = current,
                syncAnchors = emptyList(),
                syncNotice =
                    "拍子を変更したため高精度同期アンカーをリセットしました"
            )
        }

        if (
            state.isPlaying &&
            state.playbackSource ==
                ChordWikiPlaybackSource.INTERNAL
        ) {
            reanchorInternalTransport()
        }

        if (state.isPlaying) {
            restartMetronomeAligned()
        }
    }

    fun setAutoScroll(
        enabled: Boolean
    ) {
        _uiState.update {
            it.copy(autoScroll = enabled)
        }
    }

    fun setMetronomeEnabled(
        enabled: Boolean
    ) {
        _uiState.update {
            it.copy(
                metronomeEnabled = enabled
            )
        }

        if (
            enabled &&
            _uiState.value.isPlaying
        ) {
            restartMetronomeAligned()
        } else {
            stopMetronome()
        }
    }

    fun setYoutubeSyncEnabled(
        enabled: Boolean
    ) {
        val state = _uiState.value

        if (
            enabled &&
            state.selectedSong
                ?.youtubeVideoId == null
        ) {
            return
        }

        if (enabled) {
            stopInternalTransportOnly()

            val beat =
                youtubeBeatForPosition(
                    estimatedYoutubePositionMs(
                        state
                    ),
                    state
                )

            _uiState.update {
                it.copy(
                    youtubeSyncEnabled = true,
                    playbackSource =
                        ChordWikiPlaybackSource.YOUTUBE,
                    currentBeat = beat,
                    isPlaying =
                        state.youtubePlaying
                )
            }

            if (state.youtubePlaying) {
                startYoutubeTicker()
                restartMetronomeAligned()
            }
        } else {
            stopMetronome()
            stopYoutubeTicker()

            _uiState.update {
                it.copy(
                    youtubeSyncEnabled = false,
                    playbackSource =
                        ChordWikiPlaybackSource.INTERNAL,
                    isPlaying = false,
                    calibrationMode = false
                )
            }
        }
    }

    fun setYoutubeOffsetMs(
        value: Long
    ) {
        val safe =
            value.coerceIn(
                -30_000L,
                120_000L
            )

        _uiState.update { state ->
            val changed =
                state.copy(
                    youtubeOffsetMs = safe
                )

            changed.copy(
                currentBeat =
                    if (
                        changed.youtubeSyncEnabled
                    ) {
                        youtubeBeatForPosition(
                            estimatedYoutubePositionMs(
                                changed
                            ),
                            changed
                        )
                    } else {
                        changed.currentBeat
                    }
            )
        }

        if (
            _uiState.value.youtubeSyncEnabled &&
            _uiState.value.isPlaying
        ) {
            restartMetronomeAligned()
        }
    }

    fun setCalibrationMode(
        enabled: Boolean
    ) {
        val state =
            _uiState.value

        if (
            enabled &&
            state.selectedSong
                ?.youtubeVideoId == null
        ) {
            return
        }

        _uiState.update {
            it.copy(
                calibrationMode = enabled,
                youtubeSyncEnabled =
                    if (enabled) {
                        true
                    } else {
                        it.youtubeSyncEnabled
                    },
                playbackSource =
                    if (enabled) {
                        ChordWikiPlaybackSource.YOUTUBE
                    } else {
                        it.playbackSource
                    },
                syncNotice =
                    if (enabled) {
                        "動画を再生または一時停止し、開始瞬間に対応する譜面コードをタップしてください"
                    } else {
                        null
                    }
            )
        }

        if (
            enabled &&
            state.youtubePlaying
        ) {
            startYoutubeTicker()
        }
    }

    fun addSyncAnchor(
        event: TimedChordEvent
    ) {
        val state =
            _uiState.value
        val song =
            state.selectedSong
                ?: return

        if (
            song.youtubeVideoId == null
        ) {
            return
        }

        val positionMs =
            estimatedYoutubePositionMs(
                state
            )

        val candidate =
            ChordSyncAnchor(
                chartBeat =
                    event.startBeat,
                videoPositionMs =
                    positionMs,
                symbol =
                    event.symbol,
                lineIndex =
                    event.lineIndex,
                segmentIndex =
                    event.segmentIndex
            )

        if (
            !ChordSyncMap.canInsert(
                state.syncAnchors,
                candidate
            )
        ) {
            _uiState.update {
                it.copy(
                    syncNotice =
                        "この位置では前後のアンカー時刻が逆転します。動画位置を確認して再度タップしてください"
                )
            }
            return
        }

        val anchors =
            ChordSyncMap.upsert(
                state.syncAnchors,
                candidate
            )

        syncStore?.save(
            song,
            anchors
        )

        _uiState.update {
            it.copy(
                syncAnchors = anchors,
                youtubeSyncEnabled = true,
                playbackSource =
                    ChordWikiPlaybackSource.YOUTUBE,
                currentBeat =
                    event.startBeat,
                syncNotice =
                    when (anchors.size) {
                        1 ->
                            "1点固定: 開始オフセットを正確に補正しました"
                        2 ->
                            "2点固定: 曲全体の実テンポへ補正しました"
                        else ->
                            anchors.size
                                .toString() +
                                "点固定: 区間ごとのテンポ揺れを補正中"
                    }
            )
        }

        if (state.isPlaying) {
            restartMetronomeAligned()
        }
    }

    fun removeSyncAnchor(
        chartBeat: Float
    ) {
        val state =
            _uiState.value
        val song =
            state.selectedSong
                ?: return

        val anchors =
            state.syncAnchors
                .filterNot {
                    nearlySameBeat(
                        it.chartBeat,
                        chartBeat
                    )
                }

        if (anchors.isEmpty()) {
            syncStore?.clear(song)
        } else {
            syncStore?.save(
                song,
                anchors
            )
        }

        _uiState.update {
            it.copy(
                syncAnchors = anchors,
                syncNotice =
                    "同期アンカーを削除しました"
            )
        }

        if (state.isPlaying) {
            restartMetronomeAligned()
        }
    }

    fun nudgeSyncAnchor(
        chartBeat: Float,
        deltaMs: Long
    ) {
        val state =
            _uiState.value
        val song =
            state.selectedSong
                ?: return

        val current =
            state.syncAnchors
                .firstOrNull {
                    nearlySameBeat(
                        it.chartBeat,
                        chartBeat
                    )
                }
                ?: return

        val candidate =
            current.copy(
                videoPositionMs =
                    (
                        current.videoPositionMs +
                            deltaMs
                        ).coerceAtLeast(0L)
            )

        if (
            !ChordSyncMap.canInsert(
                state.syncAnchors,
                candidate
            )
        ) {
            _uiState.update {
                it.copy(
                    syncNotice =
                        "これ以上動かすと隣のアンカーと時系列が逆転します"
                )
            }
            return
        }

        val anchors =
            ChordSyncMap.upsert(
                state.syncAnchors,
                candidate
            )

        syncStore?.save(
            song,
            anchors
        )

        val changed =
            state.copy(
                syncAnchors = anchors
            )

        _uiState.update {
            changed.copy(
                currentBeat =
                    if (
                        changed.youtubeSyncEnabled
                    ) {
                        youtubeBeatForPosition(
                            estimatedYoutubePositionMs(
                                changed
                            ),
                            changed
                        )
                    } else {
                        changed.currentBeat
                    },
                syncNotice =
                    current.symbol +
                        " を " +
                        (
                            if (deltaMs >= 0L) {
                                "+"
                            } else {
                                ""
                            }
                            ) +
                        deltaMs.toString() +
                        "ms 調整"
            )
        }

        if (state.isPlaying) {
            restartMetronomeAligned()
        }
    }

    fun clearSyncAnchors() {
        val state =
            _uiState.value
        val song =
            state.selectedSong
                ?: return

        syncStore?.clear(song)

        _uiState.update {
            it.copy(
                syncAnchors = emptyList(),
                syncNotice =
                    "高精度同期をリセットしました。BPM + 開始オフセット同期に戻ります"
            )
        }

        if (state.isPlaying) {
            restartMetronomeAligned()
        }
    }

    fun videoPositionForBeat(
        beat: Float
    ): Long {
        val state =
            _uiState.value

        return syncMap(state)
            ?.videoPositionForBeat(
                beat
            )
            ?: 0L
    }

    fun toggleInternalPlayback() {
        val state = _uiState.value

        if (state.youtubeSyncEnabled) {
            return
        }

        if (
            state.isPlaying &&
            state.playbackSource ==
                ChordWikiPlaybackSource.INTERNAL
        ) {
            pauseInternalTransport()
        } else {
            startInternalTransport()
        }
    }

    fun seekToBeat(
        beat: Float
    ) {
        val state = _uiState.value
        val timeline =
            state.timeline
                ?: return

        val safe =
            beat.coerceIn(
                0f,
                timeline.totalBeats
            )

        _uiState.update {
            it.copy(currentBeat = safe)
        }

        if (
            state.isPlaying &&
            state.playbackSource ==
                ChordWikiPlaybackSource.INTERNAL
        ) {
            transportStartBeat = safe
            transportStartAtMs = nowMs()
        }

        if (state.isPlaying) {
            restartMetronomeAligned()
        }
    }

    fun onYoutubeProgress(
        positionMs: Long,
        durationMs: Long,
        playing: Boolean,
        playbackRate: Float
    ) {
        val sampleAt =
            nowMs()

        val state =
            _uiState.value

        val safeRate =
            playbackRate
                .takeIf {
                    it.isFinite() &&
                        it > 0f
                }
                ?: 1f

        val didSeek =
            detectYoutubeSeek(
                positionMs = positionMs,
                playing = playing,
                playbackRate =
                    lastYoutubePlaybackRate,
                sampleAtMs = sampleAt
            )

        lastYoutubePositionMs =
            positionMs
                .coerceAtLeast(0L)
        lastYoutubeSampleAtMs =
            sampleAt
        lastYoutubePlaybackRate =
            safeRate

        val mappedBeat =
            youtubeBeatForPosition(
                positionMs,
                state.copy(
                    youtubePlaybackRate =
                        safeRate
                )
            )

        val playbackChanged =
            state.youtubePlaying !=
                playing

        val rateChanged =
            abs(
                state.youtubePlaybackRate -
                    safeRate
            ) > 0.001f

        _uiState.update {
            it.copy(
                youtubePositionMs =
                    positionMs.coerceAtLeast(0L),
                youtubeDurationMs =
                    durationMs.coerceAtLeast(0L),
                youtubePlaying = playing,
                youtubePlaybackRate =
                    safeRate,
                currentBeat =
                    if (
                        it.youtubeSyncEnabled
                    ) {
                        mappedBeat
                    } else {
                        it.currentBeat
                    },
                playbackSource =
                    if (
                        it.youtubeSyncEnabled
                    ) {
                        ChordWikiPlaybackSource.YOUTUBE
                    } else {
                        it.playbackSource
                    },
                isPlaying =
                    if (
                        it.youtubeSyncEnabled
                    ) {
                        playing
                    } else {
                        it.isPlaying
                    }
            )
        }

        if (playing) {
            startYoutubeTicker()
        } else {
            stopYoutubeTicker()
        }

        if (
            state.youtubeSyncEnabled &&
            (
                playbackChanged ||
                    didSeek ||
                    rateChanged
                )
        ) {
            if (playing) {
                restartMetronomeAligned()
            } else {
                stopMetronome()
            }
        }
    }

    fun onYoutubeUnavailable() {
        stopMetronome()
        stopYoutubeTicker()

        _uiState.update {
            it.copy(
                youtubeSyncEnabled = false,
                youtubePlaying = false,
                youtubePlaybackRate = 1f,
                playbackSource =
                    ChordWikiPlaybackSource.INTERNAL,
                isPlaying = false,
                calibrationMode = false
            )
        }
    }

    private fun startInternalTransport() {
        val state = _uiState.value
        val timeline =
            state.timeline
                ?: return

        if (timeline.totalBeats <= 0f) {
            return
        }

        val startingBeat =
            if (
                state.currentBeat >=
                timeline.totalBeats
            ) {
                0f
            } else {
                state.currentBeat
            }

        transportStartBeat =
            startingBeat
        transportStartAtMs =
            nowMs()

        _uiState.update {
            it.copy(
                currentBeat = startingBeat,
                isPlaying = true,
                playbackSource =
                    ChordWikiPlaybackSource.INTERNAL
            )
        }

        transportJob?.cancel()
        transportJob =
            viewModelScope.launch {
                while (isActive) {
                    val current =
                        _uiState.value

                    if (
                        !current.isPlaying ||
                        current.playbackSource !=
                            ChordWikiPlaybackSource.INTERNAL
                    ) {
                        break
                    }

                    val timelineNow =
                        current.timeline
                            ?: break

                    val elapsed =
                        nowMs() -
                            transportStartAtMs

                    val beat =
                        transportStartBeat +
                            elapsed.toFloat() *
                                current.bpm /
                                60_000f

                    if (
                        beat >=
                        timelineNow.totalBeats
                    ) {
                        _uiState.update {
                            it.copy(
                                currentBeat =
                                    timelineNow
                                        .totalBeats,
                                isPlaying = false
                            )
                        }
                        stopMetronome()
                        break
                    }

                    _uiState.update {
                        it.copy(
                            currentBeat = beat
                        )
                    }

                    delay(50L)
                }
            }

        restartMetronomeAligned()
    }

    private fun pauseInternalTransport() {
        reanchorInternalTransport()
        stopInternalTransportOnly()
        stopMetronome()
        _uiState.update {
            it.copy(isPlaying = false)
        }
    }

    private fun reanchorInternalTransport() {
        val state =
            _uiState.value

        if (
            !state.isPlaying ||
            state.playbackSource !=
                ChordWikiPlaybackSource.INTERNAL
        ) {
            return
        }

        val elapsed =
            nowMs() -
                transportStartAtMs

        transportStartBeat =
            (
                transportStartBeat +
                    elapsed.toFloat() *
                        state.bpm /
                        60_000f
                ).coerceAtMost(
                state.timeline
                    ?.totalBeats
                    ?: Float.MAX_VALUE
            )

        transportStartAtMs =
            nowMs()

        _uiState.update {
            it.copy(
                currentBeat =
                    transportStartBeat
            )
        }
    }

    private fun startYoutubeTicker() {
        if (
            youtubeTickerJob
                ?.isActive == true
        ) {
            return
        }

        youtubeTickerJob =
            viewModelScope.launch {
                while (isActive) {
                    val state =
                        _uiState.value

                    if (!state.youtubePlaying) {
                        break
                    }

                    val position =
                        estimatedYoutubePositionMs(
                            state
                        )

                    _uiState.update {
                        it.copy(
                            youtubePositionMs =
                                position,
                            currentBeat =
                                if (
                                    it.youtubeSyncEnabled
                                ) {
                                    youtubeBeatForPosition(
                                        position,
                                        it
                                    )
                                } else {
                                    it.currentBeat
                                },
                            isPlaying =
                                if (
                                    it.youtubeSyncEnabled
                                ) {
                                    true
                                } else {
                                    it.isPlaying
                                }
                        )
                    }

                    delay(33L)
                }
            }
    }

    private fun stopYoutubeTicker() {
        youtubeTickerJob?.cancel()
        youtubeTickerJob = null
    }

    private fun stopInternalTransportOnly() {
        transportJob?.cancel()
        transportJob = null
    }

    private fun stopTransport() {
        stopInternalTransportOnly()
        stopYoutubeTicker()
        stopMetronome()
        _uiState.update {
            it.copy(isPlaying = false)
        }
    }

    private fun restartMetronomeAligned() {
        stopMetronome()

        val state =
            _uiState.value

        if (
            !state.metronomeEnabled ||
            !state.isPlaying
        ) {
            return
        }

        val effectiveBpm =
            effectiveMetronomeBpm(
                state
            )

        val beatFraction =
            state.currentBeat -
                floor(state.currentBeat)

        val delayMs =
            if (beatFraction < 0.02f) {
                0L
            } else {
                (
                    (1f - beatFraction) *
                        60_000f /
                        effectiveBpm
                    ).toLong()
            }

        val startingBeat =
            floor(
                state.currentBeat +
                    if (delayMs > 0L) {
                        1f
                    } else {
                        0f
                    }
            ).toInt()

        metronomeStartJob =
            viewModelScope.launch {
                if (delayMs > 0L) {
                    delay(delayMs)
                }

                val current =
                    _uiState.value

                if (
                    !current.isPlaying ||
                    !current.metronomeEnabled
                ) {
                    return@launch
                }

                val accents =
                    List(
                        current.beatsPerBar
                    ) { engineBeat ->
                        if (
                            Math.floorMod(
                                startingBeat +
                                    engineBeat,
                                current.beatsPerBar
                            ) == 0
                        ) {
                            BeatAccent.ACCENT
                        } else {
                            BeatAccent.NORMAL
                        }
                    }

                metronome.start(
                    configProvider = {
                        val latest =
                            _uiState.value

                        MetronomeConfig(
                            bpm =
                                effectiveMetronomeBpm(
                                    latest
                                ),
                            beatsPerBar =
                                latest.beatsPerBar,
                            beatUnit =
                                latest.beatUnit,
                            subdivision =
                                MetronomeSubdivision.QUARTER,
                            accents = accents,
                            countInBars = 0
                        )
                    },
                    onError = { error ->
                        _uiState.update {
                            it.copy(
                                error =
                                    error.message
                                        ?: "メトロノームを開始できませんでした"
                            )
                        }
                    }
                )
            }
    }

    private fun effectiveMetronomeBpm(
        state: ChordWikiUiState
    ): Int {
        val base =
            if (
                state.youtubeSyncEnabled
            ) {
                syncMap(state)
                    ?.localBpmAtBeat(
                        state.currentBeat
                    )
                    ?: state.bpm.toFloat()
            } else {
                state.bpm.toFloat()
            }

        val playbackScale =
            if (
                state.youtubeSyncEnabled
            ) {
                state.youtubePlaybackRate
            } else {
                1f
            }

        return (
            base * playbackScale
            ).toInt()
            .coerceIn(
                MetronomeConfig.MIN_BPM,
                MetronomeConfig.MAX_BPM
            )
    }

    private fun stopMetronome() {
        metronomeStartJob?.cancel()
        metronomeStartJob = null
        metronome.stop()
    }

    private fun youtubeBeatForPosition(
        positionMs: Long,
        state: ChordWikiUiState
    ): Float =
        syncMap(state)
            ?.beatForVideoPosition(
                positionMs
            )
            ?: 0f

    private fun syncMap(
        state: ChordWikiUiState
    ): ChordSyncMap? {
        val timeline =
            state.timeline
                ?: return null

        return ChordSyncMap(
            anchors =
                state.syncAnchors,
            fallbackBpm =
                state.bpm,
            fallbackOffsetMs =
                state.youtubeOffsetMs,
            totalBeats =
                timeline.totalBeats
        )
    }

    private fun estimatedYoutubePositionMs(
        state: ChordWikiUiState
    ): Long {
        val base =
            lastYoutubePositionMs
                ?: state.youtubePositionMs

        val sampleAt =
            lastYoutubeSampleAtMs

        if (
            !state.youtubePlaying ||
            sampleAt == null
        ) {
            return base
                .coerceAtLeast(0L)
                .coerceAtMostIfPositive(
                    state.youtubeDurationMs
                )
        }

        val elapsed =
            (
                nowMs() -
                    sampleAt
                ).coerceAtLeast(0L)

        val estimate =
            base +
                (
                    elapsed *
                        lastYoutubePlaybackRate
                    ).toLong()

        return estimate
            .coerceAtLeast(0L)
            .coerceAtMostIfPositive(
                state.youtubeDurationMs
            )
    }

    private fun detectYoutubeSeek(
        positionMs: Long,
        playing: Boolean,
        playbackRate: Float,
        sampleAtMs: Long
    ): Boolean {
        val previousPosition =
            lastYoutubePositionMs
                ?: return false

        val previousSample =
            lastYoutubeSampleAtMs
                ?: return false

        val elapsed =
            (
                sampleAtMs -
                    previousSample
                ).coerceAtLeast(0L)

        val expected =
            if (playing) {
                previousPosition +
                    (
                        elapsed *
                            playbackRate
                        ).toLong()
            } else {
                previousPosition
            }

        return abs(
            positionMs -
                expected
        ) > 700L
    }

    private fun sanitizeStoredAnchors(
        source: List<ChordSyncAnchor>,
        timeline: ChordTimeline
    ): List<ChordSyncAnchor> {
        var accepted =
            emptyList<ChordSyncAnchor>()

        source
            .filter {
                it.chartBeat in
                    0f..timeline.totalBeats &&
                    it.videoPositionMs >= 0L
            }
            .sortedBy {
                it.chartBeat
            }
            .forEach { anchor ->
                if (
                    ChordSyncMap.canInsert(
                        accepted,
                        anchor
                    )
                ) {
                    accepted =
                        ChordSyncMap.upsert(
                            accepted,
                            anchor
                        )
                }
            }

        return accepted
    }

    private fun resetYoutubeSampling() {
        stopYoutubeTicker()
        lastYoutubePositionMs = null
        lastYoutubeSampleAtMs = null
        lastYoutubePlaybackRate = 1f
    }

    private fun nearlySameBeat(
        a: Float,
        b: Float
    ): Boolean =
        abs(a - b) <
            0.0001f

    override fun onCleared() {
        searchJob?.cancel()
        loadJob?.cancel()
        stopTransport()
        resetYoutubeSampling()
    }
}

private fun Long.coerceAtMostIfPositive(
    maximum: Long
): Long =
    if (maximum > 0L) {
        coerceAtMost(maximum)
    } else {
        this
    }
