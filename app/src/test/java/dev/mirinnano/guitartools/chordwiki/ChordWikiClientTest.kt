package dev.mirinnano.guitartools.chordwiki

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChordWikiClientTest {

    @Test
    fun parsesSearchLinksAndFiltersUtilityPages() {
        val html =
            """
            <html><body>
              <a href="/wiki/Little+Busters%21">Little Busters!</a>
              <a href="/wiki.cgi?c=view&t=Song+Two&key=0">Song Two</a>
              <a href="/wiki.cgi?c=edit&t=Ignored">edit</a>
              <a href="/wiki.cgi?c=search&q=Ignored">search</a>
            </body></html>
            """.trimIndent()

        val results =
            ChordWikiClient
                .parseSearchResults(html)

        assertEquals(
            listOf(
                "Little Busters!",
                "Song Two"
            ),
            results.map { it.title }
        )

        assertTrue(
            results.all {
                it.url.startsWith(
                    "https://ja.chordwiki.org/wiki/"
                )
            }
        )
    }

    @Test
    fun extractsChordProFromEditPageTextarea() {
        val html =
            """
            <html><body>
              <textarea name="chord">{title:Test}
[C]hello &amp; [G]world</textarea>
            </body></html>
            """.trimIndent()

        val source =
            ChordWikiClient
                .extractChordSource(html)

        assertTrue(
            source.orEmpty()
                .contains("[C]hello & [G]world")
        )
        assertFalse(source.isNullOrBlank())
    }
}
