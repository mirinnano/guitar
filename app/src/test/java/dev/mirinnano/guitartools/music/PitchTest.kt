package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Test

class PitchTest {
    @Test
    fun exactA4HasZeroCents() {
        val reading = Pitch.analyze(440.0)
        assertEquals(Note.A, reading.note)
        assertEquals(4, reading.octave)
        assertEquals(0.0, reading.cents, 0.001)
    }
}
