package dev.mirinnano.guitartools.ui.tuner

import dev.mirinnano.guitartools.music.PitchReading
import dev.mirinnano.guitartools.music.Tuning

data class TunerUiState(
    val isListening: Boolean = false,
    val a4Hz: Double = 440.0,
    val selectedTuning: Tuning = Tuning.Standard,
    val reading: PitchReading? = null,
    val errorMessage: String? = null
)
