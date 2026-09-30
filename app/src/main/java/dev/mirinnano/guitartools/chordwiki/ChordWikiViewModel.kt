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
    val youtubeOffsetMs: Long = 0L
)

class ChordWikiViewModel(
    private val client: ChordWikiClient =
        ChordWikiClient(),
    private val metronome: MetronomePlayer =
        MetronomeEngine(),
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
    private var metronomeStartJob: Job? = null

    private var transportStartBeat = 0f
    private var transportStartAtMs = 0L

    private var lastYoutubePositionMs:
        Long? = null
    private var lastYoutubeSampleAtMs:
        Long? = null

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
                _uiState.update {
                    it.copy(
                        isLoadingSong = true,
                        error = null
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

                    _uiState.update {
                        it.copy(
                            selectedSong = song,
                            timeline = timeline,
                            isLoadingSong = false,
                            error = null,
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
                            youtubeOffsetMs = 0L
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
        _uiState.update {
            it.copy(
                selectedSong = null,
                timeline = null,
                isLoadingSong = false,
                error = null,
                currentBeat = 0f,
                isPlaying = false,
                youtubeSyncEnabled = false,
                youtubePositionMs = 0L,
                youtubeDurationMs = 0L,
                youtubePlaying = false
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
                            withBpm.youtubePositionMs,
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

        _uiState.update {
            it.copy(
                beatsPerBar = safeBeats,
                beatUnit = safeUnit,
                timeline = timeline,
                currentBeat = current
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
                    state.youtubePositionMs,
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
                restartMetronomeAligned()
            }
        } else {
            stopMetronome()
            _uiState.update {
                it.copy(
                    youtubeSyncEnabled = false,
                    playbackSource =
                        ChordWikiPlaybackSource.INTERNAL,
                    isPlaying = false
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
            state.copy(
                youtubeOffsetMs = safe,
                currentBeat =
                    if (
                        state.youtubeSyncEnabled
                    ) {
                        youtubeBeatForPosition(
                            state.youtubePositionMs,
                            state.copy(
                                youtubeOffsetMs =
                                    safe
                            )
                        )
                    } else {
                        state.currentBeat
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
        playing: Boolean
    ) {
        val sampleAt =
            nowMs()

        val state =
            _uiState.value

        val didSeek =
            detectYoutubeSeek(
                positionMs = positionMs,
                playing = playing,
                sampleAtMs = sampleAt
            )

        lastYoutubePositionMs =
            positionMs
        lastYoutubeSampleAtMs =
            sampleAt

        val mappedBeat =
            youtubeBeatForPosition(
                positionMs,
                state
            )

        val playbackChanged =
            state.youtubePlaying !=
                playing

        _uiState.update {
            it.copy(
                youtubePositionMs =
                    positionMs.coerceAtLeast(0L),
                youtubeDurationMs =
                    durationMs.coerceAtLeast(0L),
                youtubePlaying = playing,
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

        if (
            state.youtubeSyncEnabled &&
            (playbackChanged || didSeek)
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
        _uiState.update {
            it.copy(
                youtubeSyncEnabled = false,
                youtubePlaying = false,
                playbackSource =
                    ChordWikiPlaybackSource.INTERNAL,
                isPlaying = false
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

    private fun stopInternalTransportOnly() {
        transportJob?.cancel()
        transportJob = null
    }

    private fun stopTransport() {
        stopInternalTransportOnly()
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
                        state.bpm
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
                                latest.bpm,
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

    private fun stopMetronome() {
        metronomeStartJob?.cancel()
        metronomeStartJob = null
        metronome.stop()
    }

    private fun youtubeBeatForPosition(
        positionMs: Long,
        state: ChordWikiUiState
    ): Float {
        val timeline =
            state.timeline
                ?: return 0f

        val adjusted =
            (
                positionMs -
                    state.youtubeOffsetMs
                ).coerceAtLeast(0L)

        return timeline.beatForPositionMs(
            adjusted,
            state.bpm
        )
    }

    private fun detectYoutubeSeek(
        positionMs: Long,
        playing: Boolean,
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
                    elapsed
            } else {
                previousPosition
            }

        return abs(
            positionMs -
                expected
        ) > 1_200L
    }

    override fun onCleared() {
        searchJob?.cancel()
        loadJob?.cancel()
        stopTransport()
    }
}
