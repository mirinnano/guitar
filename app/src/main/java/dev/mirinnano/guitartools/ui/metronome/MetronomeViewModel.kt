package dev.mirinnano.guitartools.ui.metronome

import androidx.lifecycle.ViewModel
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomeEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class MetronomeViewModel(
    private val engine: MetronomeEngine = MetronomeEngine()
) : ViewModel() {

    private val _uiState = MutableStateFlow(MetronomeUiState())
    val uiState: StateFlow<MetronomeUiState> = _uiState.asStateFlow()

    fun setBpm(value: Int) {
        _uiState.update { it.copy(bpm = value.coerceIn(30, 300)) }
    }

    fun changeBpm(delta: Int) {
        setBpm(_uiState.value.bpm + delta)
    }

    fun setBeatsPerBar(value: Int) {
        _uiState.update { it.copy(beatsPerBar = value.coerceIn(1, 12)) }
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

    fun start() {
        if (_uiState.value.isPlaying) return

        _uiState.update { it.copy(isPlaying = true) }
        engine.startWithConfig {
            val state = _uiState.value
            MetronomeConfig(
                bpm = state.bpm,
                beatsPerBar = state.beatsPerBar,
                accentFirstBeat = state.accentFirstBeat
            )
        }
    }

    fun stop() {
        engine.stop()
        _uiState.update { it.copy(isPlaying = false) }
    }

    override fun onCleared() {
        engine.stop()
    }
}
