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
    fun ninthAndSixthIntervalsAreCorrect() {
        assertEquals(
            listOf(Note.C, Note.E, Note.G, Note.A),
            Chord(Note.C, ChordQuality.MAJOR_6).notes
        )

        assertEquals(
            listOf(
                Note.C,
                Note.E,
                Note.G,
                Note.A_SHARP,
                Note.D
            ),
            Chord(Note.C, ChordQuality.DOMINANT_9).notes
        )
    }

    @Test
    fun catalogueContainsEveryRootAndQuality() {
        val expectedCount =
            Note.entries.size * ChordQuality.entries.size

        assertEquals(expectedCount, CommonChords.all.size)

        Note.entries.forEach { root ->
            val shapes = CommonChords.forRoot(root)

            assertEquals(
                ChordQuality.entries.size,
                shapes.size
            )

            assertEquals(
                ChordQuality.entries.toList(),
                shapes.map { it.chord.quality }
            )
        }
    }

    @Test
    fun catalogueIsOrderedChromaticallyFromCToB() {
        val rootsInOrder = CommonChords.all
            .map { it.chord.root }
            .distinct()

        assertEquals(
            Note.entries.toList(),
            rootsInOrder
        )
    }

    @Test
    fun catalogueHasUniqueNames() {
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
    fun everyPlayedNoteBelongsToTheChord() {
        val openStringMidi =
            listOf(40, 45, 50, 55, 59, 64)

        CommonChords.all.forEach { shape ->
            val chordNotes = shape.chord.notes.toSet()

            val playedNotes = shape.frets
                .zip(openStringMidi)
                .filter { (fret, _) -> fret >= 0 }
                .map { (fret, openMidi) ->
                    Note.fromMidi(openMidi + fret)
                }
                .toSet()

            assertTrue(
                "${shape.name} contains an out-of-chord note: $playedNotes",
                playedNotes.all { it in chordNotes }
            )

            assertTrue(
                "${shape.name} does not include every chord tone",
                chordNotes.all { it in playedNotes }
            )
        }
    }
}
