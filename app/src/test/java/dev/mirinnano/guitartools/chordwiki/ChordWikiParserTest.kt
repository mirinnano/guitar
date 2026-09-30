package dev.mirinnano.guitartools.chordwiki

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChordWikiParserTest {

    @Test
    fun parsesMetadataAndKeepsChordPlacement() {
        val song =
            ChordWikiParser.parse(
                source =
                    """
                    {title:Test Song}
                    {artist:Test Artist}
                    {key:C}
                    {tempo:120}
                    [C]hello [G]world
                    [Am]again [F]end
                    """.trimIndent(),
                fallbackTitle = "Fallback",
                sourceUrl =
                    "https://ja.chordwiki.org/wiki/Test"
            )

        assertEquals("Test Song", song.title)
        assertEquals("Test Artist", song.artist)
        assertEquals("C", song.key)
        assertEquals(120, song.bpm)
        assertEquals(
            listOf("C", "G", "Am", "F"),
            song.chordSymbols
        )

        val firstLine =
            song.lines.first()

        assertEquals(
            "C",
            firstLine.segments[0].chord
        )
        assertEquals(
            "hello ",
            firstLine.segments[0].text
        )
        assertEquals(
            "G",
            firstLine.segments[1].chord
        )
        assertEquals(
            "world",
            firstLine.segments[1].text
        )
    }

    @Test
    fun keepsUnsupportedButValidChordSymbols() {
        val song =
            ChordWikiParser.parse(
                source =
                    "[F#m7b5]one [C13]two [N.C.]rest",
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        assertEquals(
            listOf("F#m7b5", "C13"),
            song.chordSymbols
        )
        assertEquals(
            "N.C.",
            song.lines.first()
                .segments.last()
                .chord
        )
    }

    @Test
    fun leavesNonChordBracketsAsLyrics() {
        val song =
            ChordWikiParser.parse(
                source =
                    "[Aメロ] [C]hello",
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        val line = song.lines.first()

        assertTrue(
            line.segments.first()
                .text.contains("[Aメロ]")
        )
        assertEquals(
            "C",
            line.segments.last().chord
        )
    }

    @Test
    fun extractsBpmFromCommentWhenNoTempoDirective() {
        val song =
            ChordWikiParser.parse(
                source =
                    """
                    {c:BPM=151}
                    [C]hello
                    """.trimIndent(),
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        assertEquals(151, song.bpm)
        assertEquals(
            ChordWikiLineType.COMMENT,
            song.lines.first().type
        )
    }
}
