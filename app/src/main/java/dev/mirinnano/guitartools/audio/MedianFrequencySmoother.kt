package dev.mirinnano.guitartools.audio

class MedianFrequencySmoother(
    private val windowSize: Int = 5
) {
    init {
        require(windowSize >= 1)
        require(windowSize % 2 == 1) { "windowSize must be odd" }
    }

    private val values = ArrayDeque<Double>(windowSize)

    fun add(frequencyHz: Double): Double {
        require(frequencyHz > 0.0)

        if (values.size == windowSize) {
            values.removeFirst()
        }
        values.addLast(frequencyHz)

        val sorted = values.sorted()
        return sorted[sorted.size / 2]
    }

    fun clear() {
        values.clear()
    }
}
