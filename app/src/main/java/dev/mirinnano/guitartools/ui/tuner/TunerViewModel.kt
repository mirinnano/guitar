package dev.mirinnano.guitartools.ui.tuner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.mirinnano.guitartools.audio.MicrophonePcmSource
import dev.mirinnano.guitartools.audio.TunerConfig
import dev.mirinnano.guitartools.audio.TunerEngine
import dev.mirinnano.guitartools.audio.YinPitchDetector
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class TunerViewModel(
    private val engine: TunerEngine = TunerEngine(
        source = MicrophonePcmSource(),
        pitchDetector = YinPitchDetector()
    )
) : ViewModel() {

    private val _uiState = MutableStateFlow(TunerUiState())
    val uiState: StateFlow<TunerUiState> = _uiState.asStateFlow()

    private var listeningJob: Job? = null

    fun setReferencePitch(a4Hz: Double) {
        val clamped = a4Hz.coerceIn(400.0, 480.0)
        _uiState.update { it.copy(a4Hz = clamped) }

        if (_uiState.value.isListening) {
            stop()
            start()
        }
    }

    fun start() {
        if (listeningJob != null) return

        val config = TunerConfig(a4Hz = _uiState.value.a4Hz)
        _uiState.update {
            it.copy(
                isListening = true,
                reading = null,
                errorMessage = null
            )
        }

        listeningJob = viewModelScope.launch {
            engine.readings(config)
                .catch { error ->
                    _uiState.update {
                        it.copy(
                            isListening = false,
                            errorMessage = error.message ?: "Microphone input failed"
                        )
                    }
                    listeningJob = null
                }
                .collect { reading ->
                    _uiState.update {
                        it.copy(
                            reading = reading,
                            errorMessage = null
                        )
                    }
                }
        }
    }

    fun stop() {
        listeningJob?.cancel()
        listeningJob = null
        _uiState.update {
            it.copy(
                isListening = false,
                reading = null
            )
        }
    }

    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    override fun onCleared() {
        listeningJob?.cancel()
    }
}
