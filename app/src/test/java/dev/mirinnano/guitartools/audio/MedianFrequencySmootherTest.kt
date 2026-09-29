package dev.mirinnano.guitartools.audio

import org.junit.Assert.assertEquals
import org.junit.Test

class MedianFrequencySmootherTest {
    @Test
    fun suppressesSingleOutlier() {
        val smoother = MedianFrequencySmoother(windowSize = 3)

        smoother.add(440.0)
        smoother.add(441.0)
        val result = smoother.add(880.0)

        assertEquals(441.0, result, 0.0001)
    }

    @Test
    fun clearDropsPreviousHistory() {
        val smoother = MedianFrequencySmoother(windowSize = 3)

        smoother.add(440.0)
        smoother.add(441.0)
        smoother.clear()

        assertEquals(220.0, smoother.add(220.0), 0.0001)
    }
}
