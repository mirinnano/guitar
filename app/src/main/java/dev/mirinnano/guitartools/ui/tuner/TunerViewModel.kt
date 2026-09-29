package dev.mirinnano.guitartools.ui.tuner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.mirinnano.guitartools.audio.MicrophonePcmSource
import dev.mirinnano.guitartools.audio.ReferenceTonePlayer
import dev.mirinnano.guitartools.audio.TonePlayer
import dev.mirinnano.guitartools.audio.TunerConfig
import dev.mirinnano.guitartools.audio.TunerEngine
import dev.mirinnano.guitartools.audio.TunerReader
import dev.mirinnano.guitartools.audio.YinPitchDetector
import dev.mirinnano.guitartools.music.PitchReading
import dev.mirinnano.guitartools.music.Tuning
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class TunerViewModel(
    private val reader: TunerReader =
        TunerEngine(
            source = MicrophonePcmSource(),
            pitchDetector =
                YinPitchDetector()
        ),
    private val tonePlayer: TonePlayer =
        ReferenceTonePlayer()
) : ViewModel() {

    private val _uiState =
        MutableStateFlow(TunerUiState())

    val uiState: StateFlow<TunerUiState> =
        _uiState.asStateFlow()

    private var listeningJob: Job? = null

    fun setReferencePitch(
        a4Hz: Double
    ) {
        _uiState.update { state ->
            retarget(
                state.copy(
                    a4Hz =
                        a4Hz.coerceIn(
                            400.0,
                            480.0
                        )
                )
            )
        }
    }

    fun setTuning(tuning: Tuning) {
        _uiState.update { state ->
            retarget(
                state.copy(
                    selectedTuning = tuning,
                    lockedStringNumber = null
                )
            )
        }
    }

    fun selectCustomTuning() {
        val current =
            _uiState.value.selectedTuning

        setTuning(
            if (current.id == "custom") {
                current
            } else {
                Tuning.CustomDefault
            }
        )
    }

    fun changeCustomString(
        stringNumber: Int,
        semitones: Int
    ) {
        _uiState.update { state ->
            val custom = if (
                state.selectedTuning.id ==
                "custom"
            ) {
                state.selectedTuning
            } else {
                Tuning.CustomDefault
            }

            val string =
                custom.strings.firstOrNull {
                    it.stringNumber ==
                        stringNumber
                } ?: return@update state

            retarget(
                state.copy(
                    selectedTuning =
                        custom.withStringMidi(
                            stringNumber,
                            string.midi +
                                semitones
                        )
                )
            )
        }
    }

    fun setLockedString(
        stringNumber: Int?
    ) {
        _uiState.update { state ->
            retarget(
                state.copy(
                    lockedStringNumber =
                        stringNumber
                )
            )
        }
    }

    fun setSensitivity(value: Float) {
        _uiState.update {
            it.copy(
                sensitivity =
                    value.coerceIn(
                        0f,
                        1f
                    )
            )
        }
    }

    fun setHapticEnabled(
        enabled: Boolean
    ) {
        _uiState.update {
            it.copy(
                hapticEnabled = enabled
            )
        }
    }

    fun playReferenceString(
        stringNumber: Int
    ) {
        val state = _uiState.value
        val string =
            state.selectedTuning
                .strings
                .firstOrNull {
                    it.stringNumber ==
                        stringNumber
                } ?: return

        tonePlayer.play(
            dev.mirinnano.guitartools.music
                .Note.frequencyForMidi(
                    string.midi,
                    state.a4Hz
                )
        )
    }

    fun start() {
        if (listeningJob != null) return

        _uiState.update {
            it.copy(
                isListening = true,
                reading = null,
                target = null,
                errorMessage = null
            )
        }

        listeningJob =
            viewModelScope.launch {
                reader.readings {
                    val state =
                        _uiState.value

                    TunerConfig(
                        a4Hz = state.a4Hz,
                        minimumRms =
                            sensitivityToRms(
                                state.sensitivity
                            )
                    )
                }
                    .catch { error ->
                        _uiState.update {
                            it.copy(
                                isListening =
                                    false,
                                reading = null,
                                target = null,
                                errorMessage =
                                    error.message
                                        ?: "Microphone input failed"
                            )
                        }
                        listeningJob = null
                    }
                    .collect { reading ->
                        _uiState.update {
                                state ->
                            retarget(
                                state.copy(
                                    reading =
                                        reading,
                                    errorMessage =
                                        null
                                )
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
                reading = null,
                target = null
            )
        }
    }

    fun clearError() {
        _uiState.update {
            it.copy(
                errorMessage = null
            )
        }
    }

    private fun retarget(
        state: TunerUiState
    ): TunerUiState {
        val reading =
            state.reading
                ?: return state.copy(
                    target = null
                )

        val target =
            state.lockedStringNumber
                ?.let { stringNumber ->
                    state.selectedTuning
                        .targetForString(
                            stringNumber =
                                stringNumber,
                            frequencyHz =
                                reading.frequencyHz,
                            a4Hz =
                                state.a4Hz
                        )
                }
                ?: state.selectedTuning
                    .closestString(
                        frequencyHz =
                            reading.frequencyHz,
                        a4Hz = state.a4Hz
                    )

        return state.copy(
            target = target
        )
    }

    private fun sensitivityToRms(
        sensitivity: Float
    ): Double {
        val minThreshold = 0.003
        val maxThreshold = 0.025

        return maxThreshold -
            sensitivity *
                (
                    maxThreshold -
                        minThreshold
                    )
    }

    override fun onCleared() {
        listeningJob?.cancel()
        tonePlayer.stop()
    }
}
