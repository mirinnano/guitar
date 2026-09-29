package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChordTest {

    @Test
    fun majorSevenContainsExpectedNotes() {
        val chord = Chord(Note.C, ChordQuality.MAJOR_7)

        assertEquals(
            listOf(Note.C, Note.E, Note.G, Note.B),
            chord.notes
        )
    }

    @Test
    fun suspendedAndPowerChordIntervalsAreCorrect() {
        assertEquals(
            listOf(Note.D, Note.E, Note.A),
            Chord(Note.D, ChordQuality.SUS_2).notes
        )

        assertEquals(
            listOf(Note.E, Note.B),
            Chord(Note.E, ChordQuality.POWER_5).notes
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

    @Test
    fun everyShapeContainsSixStrings() {
        CommonChords.all.forEach { shape ->
            assertEquals(6, shape.frets.size)
            assertEquals(6, shape.fingers.size)
        }
    }

    @Test
    fun fMajorContainsFullBarre() {
        val fMajor = CommonChords.all.first {
            it.name == "F"
        }

        assertTrue(
            fMajor.barres.contains(
                Barre(
                    fret = 1,
                    fromString = 6,
                    toString = 1
                )
            )
        )
    }
}
