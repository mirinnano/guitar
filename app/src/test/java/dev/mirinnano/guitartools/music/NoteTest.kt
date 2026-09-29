package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Test

class NoteTest {
    @Test
    fun a4IsMidi69And440Hz() {
        assertEquals(Note.A, Note.fromMidi(69))
        assertEquals(4, Note.octaveForMidi(69))
        assertEquals(440.0, Note.frequencyForMidi(69), 0.0001)
        assertEquals(69, Note.nearestMidi(440.0))
    }

    @Test
    fun negativeMidiWrapsCorrectly() {
        assertEquals(Note.B, Note.fromMidi(-1))
    }
}
