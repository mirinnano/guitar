package dev.mirinnano.guitartools.ui.metronome

import dev.mirinnano.guitartools.audio.MetronomeConfig

data class MetronomeUiState(
    val bpm: Int = MetronomeConfig.DEFAULT_BPM,
    val beatsPerBar: Int = MetronomeConfig.DEFAULT_BEATS_PER_BAR,
    val accentFirstBeat: Boolean = true,
    val isPlaying: Boolean = false,
    val playbackFailed: Boolean = false
)
