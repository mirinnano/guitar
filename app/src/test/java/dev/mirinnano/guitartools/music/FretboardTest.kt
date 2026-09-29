package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Test

class FretboardTest {
    @Test
    fun lowEAtTwelfthFretIsE3() {
        val lowE = Tuning.Standard.strings.first { it.stringNumber == 6 }
        val position = Fretboard.position(lowE, 12)

        assertEquals(Note.E, position.note)
        assertEquals(3, position.octave)
        assertEquals(52, position.midi)
    }
}
