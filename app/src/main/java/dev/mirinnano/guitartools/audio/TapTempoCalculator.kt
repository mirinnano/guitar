package dev.mirinnano.guitartools.audio

import kotlin.math.roundToInt

class TapTempoCalculator(
    private val maxTapCount: Int = 5,
    private val resetAfterMillis: Long = 2_000L
) {
    init {
        require(maxTapCount >= 2)
        require(resetAfterMillis > 0)
    }

    private val taps = ArrayDeque<Long>(maxTapCount)

    fun tap(timestampMillis: Long): Int? {
        val previous = taps.lastOrNull()

        if (
            previous != null &&
            (timestampMillis <= previous || timestampMillis - previous > resetAfterMillis)
        ) {
            taps.clear()
        }

        taps.addLast(timestampMillis)
        while (taps.size > maxTapCount) {
            taps.removeFirst()
        }

        if (taps.size < 2) return null

        val values = taps.toList()
        val intervals = values.zipWithNext { first, second -> second - first }
        val averageMillis = intervals.average()

        if (averageMillis <= 0.0) return null

        return (60_000.0 / averageMillis)
            .roundToInt()
            .coerceIn(30, 300)
    }

    fun reset() {
        taps.clear()
    }
}
