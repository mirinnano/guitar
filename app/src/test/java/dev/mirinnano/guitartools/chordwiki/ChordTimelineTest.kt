package dev.mirinnano.guitartools.chordwiki

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class ChordTimelineTest {

    @Test
    fun dividesOneLineBarAcrossChords() {
        val song =
            ChordWikiParser.parse(
                source = "[C]hello [G]world",
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        val timeline =
            ChordTimelineBuilder.build(song)

        assertEquals(4f, timeline.totalBeats)
        assertEquals(2, timeline.events.size)
        assertEquals(
            0f,
            timeline.events[0].startBeat
        )
        assertEquals(
            2f,
            timeline.events[0].durationBeats
        )
        assertEquals(
            2f,
            timeline.events[1].startBeat
        )
    }

    @Test
    fun explicitBarsCreateSeparateBars() {
        val song =
            ChordWikiParser.parse(
                source = "[C]one | [G]two |",
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        val timeline =
            ChordTimelineBuilder.build(song)

        assertEquals(8f, timeline.totalBeats)
        assertEquals(
            0f,
            timeline.events[0].startBeat
        )
        assertEquals(
            4f,
            timeline.events[1].startBeat
        )
    }

    @Test
    fun activeChordFollowsBeat() {
        val song =
            ChordWikiParser.parse(
                source = "[C]hello [G]world",
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        val timeline =
            ChordTimelineBuilder.build(song)

        assertEquals(
            "C",
            timeline.activeEvent(1f)?.symbol
        )
        assertEquals(
            "G",
            timeline.activeEvent(3f)?.symbol
        )
    }

    @Test
    fun finalChordStopsAtItsAssignedEnd() {
        val song =
            ChordWikiParser.parse(
                source =
                    """
                    [C]hello
                    lyrics only
                    """.trimIndent(),
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        val timeline =
            ChordTimelineBuilder.build(song)

        assertEquals(
            null,
            timeline.activeEvent(5f)
        )
    }

    @Test
    fun usesSongMeterByDefault() {
        val song =
            ChordWikiParser.parse(
                source =
                    """
                    {time:3/4}
                    [C]hello [G]world
                    """.trimIndent(),
                fallbackTitle = "Test",
                sourceUrl = "https://example.com"
            )

        val timeline =
            ChordTimelineBuilder.build(song)

        assertEquals(3, timeline.beatsPerBar)
        assertEquals(3f, timeline.totalBeats)
    }
}
