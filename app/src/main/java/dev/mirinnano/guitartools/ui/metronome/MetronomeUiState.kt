package dev.mirinnano.guitartools.ui.metronome

import dev.mirinnano.guitartools.audio.BeatAccent
import dev.mirinnano.guitartools.audio.ClickSound
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomeSubdivision

data class MetronomeUiState(
    val bpm: Int = MetronomeConfig.DEFAULT_BPM,
    val beatsPerBar: Int = MetronomeConfig.DEFAULT_BEATS_PER_BAR,
    val beatUnit: Int = 4,
    val subdivision: MetronomeSubdivision =
        MetronomeSubdivision.QUARTER,
    val accents: List<BeatAccent> =
        MetronomeConfig.defaultAccents(
            MetronomeConfig.DEFAULT_BEATS_PER_BAR
        ),
    val clickSound: ClickSound = ClickSound.DIGITAL,
    val countInBars: Int = 0,
    val currentBeat: Int? = null,
    val currentSubdivision: Int = 0,
    val isCountIn: Boolean = false,
    val isPlaying: Boolean = false,
    val playbackFailed: Boolean = false,
    val speedTrainerEnabled: Boolean = false,
    val speedStartBpm: Int = 60,
    val speedEndBpm: Int = 120,
    val speedStepBpm: Int = 5,
    val speedBarsPerStep: Int = 4,
    val speedCompletedBars: Int = 0
)
