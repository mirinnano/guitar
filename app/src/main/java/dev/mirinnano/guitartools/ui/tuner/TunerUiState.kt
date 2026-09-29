package dev.mirinnano.guitartools.ui.tuner

import dev.mirinnano.guitartools.music.PitchReading
import dev.mirinnano.guitartools.music.Tuning
import dev.mirinnano.guitartools.music.TuningTarget

data class TunerUiState(
    val isListening: Boolean = false,
    val a4Hz: Double = 440.0,
    val selectedTuning:
        Tuning = Tuning.Standard,
    val lockedStringNumber: Int? = null,
    val sensitivity: Float = 0.6f,
    val hapticEnabled: Boolean = true,
    val reading: PitchReading? = null,
    val target: TuningTarget? = null,
    val errorMessage: String? = null
)
