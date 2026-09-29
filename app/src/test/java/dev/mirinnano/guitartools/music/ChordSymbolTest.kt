package dev.mirinnano.guitartools.music

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ChordSymbolTest {

    @Test
    fun flatsAreNormalizedToSharpCatalogueNames() {
        assertEquals(
            "A#maj7",
            normalizeChordLookup("Bbmaj7")
        )
    }

    @Test
    fun slashBassKeepsBaseChordForDiagramLookup() {
        assertEquals(
            "F#m7",
            normalizeChordLookup("F#m7/C#")
        )
    }

    @Test
    fun commonAliasesAreNormalized() {
        assertEquals(
            "Dsus4",
            normalizeChordLookup("Dsus")
        )
        assertEquals(
            "Cmaj7",
            normalizeChordLookup("C△7")
        )
    }

    @Test
    fun noChordMarkerIsIgnored() {
        assertNull(
            normalizeChordLookup("N.C.")
        )
    }
}
