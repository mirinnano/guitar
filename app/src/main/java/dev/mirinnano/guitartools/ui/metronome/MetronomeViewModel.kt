package dev.mirinnano.guitartools.ui.metronome

import androidx.lifecycle.ViewModel
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomeEngine
import dev.mirinnano.guitartools.audio.MetronomePlayer
import dev.mirinnano.guitartools.audio.TapTempoCalculator
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class MetronomeViewModel(
    private val player: MetronomePlayer = MetronomeEngine(),
    private val tapTempo: TapTempoCalculator = TapTempoCalculator(),
    private val nowMillis: () -> Long = { System.nanoTime() / 1_000_000L }
) : ViewModel() {

    private val _uiState = MutableStateFlow(MetronomeUiState())
    val uiState: StateFlow<MetronomeUiState> = _uiState.asStateFlow()

    fun setBpm(bpm: Int) {
        tapTempo.reset()
        updateBpm(bpm)
    }

    fun changeBpm(delta: Int) {
        tapTempo.reset()
        updateBpm(_uiState.value.bpm + delta)
    }

    fun registerTempoTap() {
        tapTempo.tap(nowMillis())?.let(::updateBpm)
    }

    fun setBeatsPerBar(beats: Int) {
        _uiState.update {
            it.copy(
                beatsPerBar = beats.coerceIn(
                    MetronomeConfig.MIN_BEATS_PER_BAR,
                    MetronomeConfig.MAX_BEATS_PER_BAR
                )
            )
        }
    }

    fun setAccentFirstBeat(enabled: Boolean) {
        _uiState.update { it.copy(accentFirstBeat = enabled) }
    }

    fun togglePlayback() {
        if (_uiState.value.isPlaying) {
            stop()
        } else {
            start()
        }
    }

    fun dismissPlaybackError() {
        _uiState.update { it.copy(playbackFailed = false) }
    }

    private fun start() {
        if (_uiState.value.isPlaying) return

        _uiState.update {
            it.copy(
                isPlaying = true,
                playbackFailed = false
            )
        }

        player.start(
            configProvider = ::currentConfig,
            onError = {
                _uiState.update {
                    it.copy(
                        isPlaying = false,
                        playbackFailed = true
                    )
                }
            }
        )
    }

    private fun stop() {
        player.stop()
        _uiState.update { it.copy(isPlaying = false) }
    }

    private fun currentConfig(): MetronomeConfig {
        val state = _uiState.value

        return MetronomeConfig(
            bpm = state.bpm,
            beatsPerBar = state.beatsPerBar,
            accentFirstBeat = state.accentFirstBeat
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
