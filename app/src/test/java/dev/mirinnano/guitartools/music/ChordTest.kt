package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChordTest {
    @Test
    fun majorSevenContainsExpectedIntervals() {
        val chord = Chord(Note.C, ChordQuality.MAJOR_7)

        assertEquals(
            listOf(Note.C, Note.E, Note.G, Note.B),
            chord.notes
        )
    }

    @Test
    fun minorSevenContainsExpectedIntervals() {
        val chord = Chord(Note.A, ChordQuality.MINOR_7)

        assertEquals(
            listOf(Note.A, Note.C, Note.E, Note.G),
            chord.notes
        )
    }

    @Test
    fun commonLibraryCoversEverySupportedQuality() {
        val qualities = CommonChords.all
            .map { it.chord.quality }
            .toSet()

        ChordQuality.entries.forEach { quality ->
            assertTrue(quality in qualities)
        }
    }

    @Test
    fun commonLibraryHasUniqueNames() {
        val names = CommonChords.all.map { it.name }

        assertEquals(names.size, names.toSet().size)
    }
}
