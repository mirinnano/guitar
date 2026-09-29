package dev.mirinnano.guitartools.practice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChordProParserTest {

    @Test
    fun parsesMetadataAndChordSequence() {
        val chart = ChordProParser.parse(
            """
            {title:Test Song}
            {artist:Test Artist}
            {tempo:96}
            [C]hello [G]world
            [Am]again [F]end
            """.trimIndent()
        )

        assertEquals(
            "Test Song",
            chart.title
        )
        assertEquals(
            "Test Artist",
            chart.artist
        )
        assertEquals(96, chart.bpm)
        assertEquals(
            listOf("C", "G", "Am", "F"),
            chart.steps.map {
                it.lookupName
            }
        )
    }

    @Test
    fun normalizesFlatsAndSlashChords() {
        val chart = ChordProParser.parse(
            "[Bb]one [F/A]two [Ebmaj7]three"
        )

        assertEquals(
            listOf(
                "A#",
                "F",
                "D#maj7"
            ),
            chart.steps.map {
                it.lookupName
            }
        )
    }

    @Test
    fun skipsUnsupportedChordSymbols() {
        val chart =
            ChordProParser.parse(
                "[C13]x [C]ok"
            )

        assertEquals(1, chart.steps.size)
        assertTrue(
            chart.steps.first()
                .lookupName == "C"
        )
    }
}
