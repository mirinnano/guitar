package dev.mirinnano.guitartools.practice

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.mirinnano.guitartools.audio.BeatEvent
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomeEngine
import dev.mirinnano.guitartools.audio.MetronomePlayer
import dev.mirinnano.guitartools.audio.MetronomeSubdivision
import dev.mirinnano.guitartools.music.normalizeChordLookup
import dev.mirinnano.guitartools.song.SongCatalogRepository
import dev.mirinnano.guitartools.song.SongSearchProvider
import dev.mirinnano.guitartools.song.SongSearchResult
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class PracticeViewModel(
    private val metronome: MetronomePlayer =
        MetronomeEngine(),
    private val songProvider: SongSearchProvider =
        SongCatalogRepository()
) : ViewModel() {

    private val _uiState =
        MutableStateFlow(PracticeUiState())

    val uiState: StateFlow<PracticeUiState> =
        _uiState.asStateFlow()

    private var searchJob: Job? = null

    fun setBpm(value: Int) {
        _uiState.update {
            it.copy(
                bpm = value.coerceIn(
                    MetronomeConfig.MIN_BPM,
                    MetronomeConfig.MAX_BPM
                )
            )
        }
    }

    fun setAutoScroll(enabled: Boolean) {
        _uiState.update {
            it.copy(autoScroll = enabled)
        }
    }

    fun setImportText(text: String) {
        _uiState.update {
            it.copy(importText = text)
        }
    }

    fun importChordPro() {
        val state = _uiState.value
        val chart =
            ChordProParser.parse(
                state.importText
            )

        if (chart.steps.isEmpty()) {
            _uiState.update {
                it.copy(
                    searchError =
                        "コードを認識できませんでした"
                )
            }
            return
        }

        stop()

        _uiState.update {
            it.copy(
                title = chart.title,
                artist = chart.artist,
                progression = chart.steps,
                bpm = (
                    chart.bpm ?: it.bpm
                    ).coerceIn(
                        MetronomeConfig.MIN_BPM,
                        MetronomeConfig.MAX_BPM
                    ),
                currentStepIndex = 0,
                beatInStep = 0,
                searchError = null
            )
        }
    }

    fun addChord(
        rawSymbol: String
    ) {
        val lookup =
            normalizeChordLookup(rawSymbol)
                ?: return

        _uiState.update {
            it.copy(
                progression =
                    it.progression +
                        ProgressionStep(
                            symbol = rawSymbol,
                            lookupName = lookup
                        )
            )
        }
    }

    fun removeStep(index: Int) {
        _uiState.update { state ->
            if (
                index !in
                state.progression.indices
            ) {
                state
            } else {
                val updated =
                    state.progression
                        .toMutableList()
                        .also {
                            it.removeAt(index)
                        }

                state.copy(
                    progression = updated,
                    currentStepIndex =
                        if (updated.isEmpty()) {
                            0
                        } else {
                            state.currentStepIndex
                                .coerceAtMost(
                                    updated.lastIndex
                                )
                        },
                    beatInStep = 0
                )
            }
        }
    }

    fun setStepBeats(
        index: Int,
        beats: Int
    ) {
        _uiState.update { state ->
            if (
                index !in
                state.progression.indices
            ) {
                state
            } else {
                val updated =
                    state.progression
                        .toMutableList()

                updated[index] =
                    updated[index].copy(
                        beats =
                            beats.coerceIn(
                                1,
                                32
                            )
                    )

                state.copy(
                    progression = updated
                )
            }
        }
    }

    fun setSearchQuery(query: String) {
        _uiState.update {
            it.copy(searchQuery = query)
        }
    }

    fun searchSongs() {
        val query =
            _uiState.value.searchQuery
                .trim()

        if (query.isBlank()) return

        searchJob?.cancel()
        searchJob =
            viewModelScope.launch {
                _uiState.update {
                    it.copy(
                        isSearching = true,
                        searchError = null
                    )
                }

                runCatching {
                    songProvider.search(query)
                }.onSuccess { results ->
                    _uiState.update {
                        it.copy(
                            searchResults =
                                results,
                            isSearching = false
                        )
                    }
                }.onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isSearching = false,
                            searchError =
                                error.message
                                    ?: "検索に失敗しました"
                        )
                    }
                }
            }
    }

    fun selectSong(
        song: SongSearchResult
    ) {
        _uiState.update { state ->
            state.copy(
                selectedSong = song,
                title = song.title,
                artist = song.artist,
                bpm = (
                    song.bpm ?: state.bpm
                    ).coerceIn(
                        MetronomeConfig.MIN_BPM,
                        MetronomeConfig.MAX_BPM
                    )
            )
        }
    }

    fun syncToPlaybackPosition(
        positionMs: Long
    ) {
        _uiState.update { state ->
            if (
                state.progression.isEmpty() ||
                positionMs < 0L
            ) {
                return@update state
            }

            val totalBeats =
                state.progression.sumOf {
                    it.beats
                }

            if (totalBeats <= 0) {
                return@update state
            }

            val absoluteBeat =
                (
                    positionMs.toDouble() *
                        state.bpm /
                        60_000.0
                    ).toInt()
                    .coerceAtLeast(0)
                    .coerceAtMost(
                        totalBeats - 1
                    )

            var remaining =
                absoluteBeat
            var targetIndex = 0
            var beatInStep = 0

            state.progression
                .forEachIndexed {
                        index,
                        step ->

                    if (
                        remaining <
                        step.beats
                    ) {
                        targetIndex =
                            index
                        beatInStep =
                            remaining
                        return@forEachIndexed
                    }

                    remaining -=
                        step.beats
                }

            state.copy(
                currentStepIndex =
                    targetIndex,
                beatInStep =
                    beatInStep
            )
        }
    }

    fun togglePlayback() {
        if (_uiState.value.isPlaying) {
            stop()
        } else {
            start()
        }
    }

    fun restart() {
        _uiState.update {
            it.copy(
                currentStepIndex = 0,
                beatInStep = 0
            )
        }
    }

    private fun start() {
        val state = _uiState.value

        if (
            state.isPlaying ||
            state.progression.isEmpty()
        ) {
            return
        }

        _uiState.update {
            it.copy(
                isPlaying = true,
                currentStepIndex =
                    it.currentStepIndex
                        .coerceIn(
                            0,
                            it.progression.lastIndex
                        ),
                beatInStep = 0
            )
        }

        metronome.start(
            configProvider = {
                val current =
                    _uiState.value

                MetronomeConfig(
                    bpm = current.bpm,
                    beatsPerBar =
                        current.beatsPerBar,
                    subdivision =
                        MetronomeSubdivision.QUARTER,
                    accents =
                        MetronomeConfig
                            .defaultAccents(
                                current.beatsPerBar
                            ),
                    countInBars = 1
                )
            },
            onBeat = ::onBeat,
            onError = {
                _uiState.update {
                    it.copy(
                        isPlaying = false
                    )
                }
            }
        )
    }

    private fun stop() {
        metronome.stop()
        _uiState.update {
            it.copy(
                isPlaying = false,
                beatInStep = 0
            )
        }
    }

    private fun onBeat(
        event: BeatEvent
    ) {
        if (
            !event.isMainBeat ||
            event.isCountIn
        ) {
            return
        }

        _uiState.update { state ->
            val progression =
                state.progression

            if (progression.isEmpty()) {
                return@update state
            }

            val index =
                state.currentStepIndex
                    .coerceIn(
                        0,
                        progression.lastIndex
                    )

            val step =
                progression[index]

            val nextBeat =
                state.beatInStep + 1

            if (nextBeat < step.beats) {
                state.copy(
                    beatInStep = nextBeat
                )
            } else {
                state.copy(
                    currentStepIndex =
                        (index + 1) %
                            progression.size,
                    beatInStep = 0
                )
            }
        }
    }

    override fun onCleared() {
        searchJob?.cancel()
        metronome.stop()
    }
}
