package dev.mirinnano.guitartools.ui.metronome

import androidx.lifecycle.ViewModel
import dev.mirinnano.guitartools.audio.BeatAccent
import dev.mirinnano.guitartools.audio.BeatEvent
import dev.mirinnano.guitartools.audio.ClickSound
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomeEngine
import dev.mirinnano.guitartools.audio.MetronomePlayer
import dev.mirinnano.guitartools.audio.MetronomeSubdivision
import dev.mirinnano.guitartools.audio.TapTempoCalculator
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class MetronomeViewModel(
    private val player: MetronomePlayer =
        MetronomeEngine(),
    private val tapTempo: TapTempoCalculator =
        TapTempoCalculator(),
    private val nowMillis: () -> Long = {
        System.nanoTime() / 1_000_000L
    }
) : ViewModel() {

    private val _uiState =
        MutableStateFlow(MetronomeUiState())

    val uiState: StateFlow<MetronomeUiState> =
        _uiState.asStateFlow()

    fun setBpm(bpm: Int) {
        tapTempo.reset()
        updateBpm(bpm)
    }

    fun changeBpm(delta: Int) {
        tapTempo.reset()
        updateBpm(
            _uiState.value.bpm + delta
        )
    }

    fun registerTempoTap() {
        tapTempo
            .tap(nowMillis())
            ?.let(::updateBpm)
    }

    fun setTimeSignature(
        beatsPerBar: Int,
        beatUnit: Int
    ) {
        val beats = beatsPerBar.coerceIn(
            MetronomeConfig.MIN_BEATS_PER_BAR,
            MetronomeConfig.MAX_BEATS_PER_BAR
        )

        _uiState.update { state ->
            state.copy(
                beatsPerBar = beats,
                beatUnit = beatUnit,
                accents = List(beats) { index ->
                    state.accents.getOrNull(index)
                        ?: if (index == 0) {
                            BeatAccent.ACCENT
                        } else {
                            BeatAccent.NORMAL
                        }
                }
            )
        }
    }

    fun setSubdivision(
        subdivision: MetronomeSubdivision
    ) {
        _uiState.update {
            it.copy(subdivision = subdivision)
        }
    }

    fun cycleAccent(index: Int) {
        _uiState.update { state ->
            if (index !in state.accents.indices) {
                state
            } else {
                val updated =
                    state.accents.toMutableList()

                updated[index] = when (
                    updated[index]
                ) {
                    BeatAccent.ACCENT ->
                        BeatAccent.NORMAL
                    BeatAccent.NORMAL ->
                        BeatAccent.MUTE
                    BeatAccent.MUTE ->
                        BeatAccent.ACCENT
                }

                state.copy(accents = updated)
            }
        }
    }

    fun setClickSound(sound: ClickSound) {
        _uiState.update {
            it.copy(clickSound = sound)
        }
    }

    fun setCountInBars(bars: Int) {
        _uiState.update {
            it.copy(
                countInBars = bars.coerceIn(
                    0,
                    MetronomeConfig.MAX_COUNT_IN_BARS
                )
            )
        }
    }

    fun setSpeedTrainerEnabled(enabled: Boolean) {
        _uiState.update { state ->
            state.copy(
                speedTrainerEnabled = enabled,
                speedCompletedBars = 0,
                bpm = if (enabled) {
                    state.speedStartBpm
                } else {
                    state.bpm
                }
            )
        }
    }

    fun setSpeedStartBpm(value: Int) {
        _uiState.update { state ->
            val start = value.coerceIn(
                MetronomeConfig.MIN_BPM,
                state.speedEndBpm
            )
            state.copy(
                speedStartBpm = start,
                bpm = if (
                    state.speedTrainerEnabled &&
                    !state.isPlaying
                ) {
                    start
                } else {
                    state.bpm
                }
            )
        }
    }

    fun setSpeedEndBpm(value: Int) {
        _uiState.update { state ->
            state.copy(
                speedEndBpm = value.coerceIn(
                    state.speedStartBpm,
                    MetronomeConfig.MAX_BPM
                )
            )
        }
    }

    fun setSpeedStepBpm(value: Int) {
        _uiState.update {
            it.copy(
                speedStepBpm =
                    value.coerceIn(1, 20)
            )
        }
    }

    fun setSpeedBarsPerStep(value: Int) {
        _uiState.update {
            it.copy(
                speedBarsPerStep =
                    value.coerceIn(1, 16)
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

    fun dismissPlaybackError() {
        _uiState.update {
            it.copy(playbackFailed = false)
        }
    }

    private fun start() {
        if (_uiState.value.isPlaying) return

        _uiState.update { state ->
            state.copy(
                isPlaying = true,
                playbackFailed = false,
                speedCompletedBars = 0,
                currentBeat = null,
                isCountIn =
                    state.countInBars > 0,
                bpm = if (
                    state.speedTrainerEnabled
                ) {
                    state.speedStartBpm
                } else {
                    state.bpm
                }
            )
        }

        player.start(
            configProvider = ::currentConfig,
            onBeat = ::onBeat,
            onError = {
                _uiState.update {
                    it.copy(
                        isPlaying = false,
                        playbackFailed = true,
                        currentBeat = null
                    )
                }
            }
        )
    }

    private fun stop() {
        player.stop()
        _uiState.update {
            it.copy(
                isPlaying = false,
                currentBeat = null,
                currentSubdivision = 0,
                isCountIn = false
            )
        }
    }

    private fun onBeat(event: BeatEvent) {
        _uiState.update { state ->
            var next = state.copy(
                currentBeat = event.beatInBar,
                currentSubdivision =
                    event.subdivisionIndex,
                isCountIn = event.isCountIn
            )

            if (
                state.speedTrainerEnabled &&
                !event.isCountIn &&
                event.isMainBeat &&
                event.beatInBar ==
                    state.beatsPerBar - 1
            ) {
                val completed =
                    state.speedCompletedBars + 1

                if (
                    completed >=
                    state.speedBarsPerStep &&
                    state.bpm <
                    state.speedEndBpm
                ) {
                    next = next.copy(
                        bpm = (
                            state.bpm +
                                state.speedStepBpm
                            ).coerceAtMost(
                                state.speedEndBpm
                            ),
                        speedCompletedBars = 0
                    )
                } else {
                    next = next.copy(
                        speedCompletedBars =
                            completed
                    )
                }
            }

            next
        }
    }

    private fun currentConfig(): MetronomeConfig {
        val state = _uiState.value

        return MetronomeConfig(
            bpm = state.bpm,
            beatsPerBar = state.beatsPerBar,
            beatUnit = state.beatUnit,
            subdivision = state.subdivision,
            accents = state.accents,
            clickSound = state.clickSound,
            countInBars = state.countInBars
        )
    }

    private fun updateBpm(bpm: Int) {
        _uiState.update {
            it.copy(
                bpm = bpm.coerceIn(
                    MetronomeConfig.MIN_BPM,
                    MetronomeConfig.MAX_BPM
                )
            )
        }
    }

    override fun onCleared() {
        player.stop()
    }
}
