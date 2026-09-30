package dev.mirinnano.guitartools.chordwiki

enum class ChordWikiLineType {
    CONTENT,
    COMMENT,
    BLANK
}

data class ChordWikiSegment(
    val chord: String? = null,
    val text: String = ""
)

data class ChordWikiLine(
    val segments: List<ChordWikiSegment> = emptyList(),
    val type: ChordWikiLineType = ChordWikiLineType.CONTENT
) {
    val chordSymbols: List<String>
        get() = segments.mapNotNull { it.chord }
}

data class ChordWikiSong(
    val pageTitle: String,
    val title: String,
    val artist: String = "",
    val key: String? = null,
    val bpm: Int? = null,
    val lines: List<ChordWikiLine>,
    val sourceUrl: String
) {
    val chordSymbols: List<String>
        get() = lines
            .flatMap { it.chordSymbols }
            .filterNot {
                it.equals("N.C.", ignoreCase = true) ||
                    it.equals("NC", ignoreCase = true) ||
                    it == "<"
            }
            .distinct()
}

data class ChordWikiSearchResult(
    val title: String,
    val url: String
)
