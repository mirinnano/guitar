package dev.mirinnano.guitartools.ui.tuner

import dev.mirinnano.guitartools.music.PitchReading

data class TunerUiState(
    val isListening: Boolean = false,
    val a4Hz: Double = 440.0,
    val reading: PitchReading? = null,
    val errorMessage: String? = null
)
