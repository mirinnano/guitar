package dev.mirinnano.guitartools.audio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TapTempoCalculatorTest {
    @Test
    fun calculatesTempoFromTapIntervals() {
        val calculator = TapTempoCalculator()

        assertNull(calculator.tap(0L))
        assertEquals(120, calculator.tap(500L))
        assertEquals(120, calculator.tap(1_000L))
        assertEquals(120, calculator.tap(1_500L))
    }

    @Test
    fun resetsAfterLongPause() {
        val calculator = TapTempoCalculator(resetAfterMillis = 2_000L)

        calculator.tap(0L)
        calculator.tap(500L)

        assertNull(calculator.tap(3_000L))
        assertEquals(100, calculator.tap(3_600L))
    }
}
