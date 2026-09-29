package dev.mirinnano.guitartools.ui.metronome

data class MetronomeUiState(
    val bpm: Int = 120,
    val beatsPerBar: Int = 4,
    val accentFirstBeat: Boolean = true,
    val isPlaying: Boolean = false
)
