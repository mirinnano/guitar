package dev.mirinnano.guitartools.practice

data class ProgressionStep(
    val symbol: String,
    val lookupName: String,
    val beats: Int = 4
) {
    init {
        require(beats in 1..32)
    }
}

data class ChordChart(
    val title: String,
    val artist: String = "",
    val bpm: Int? = null,
    val steps: List<ProgressionStep>
)
