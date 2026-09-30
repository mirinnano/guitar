package dev.mirinnano.guitartools.chordwiki

object ChordWikiParser {

    private val directivePattern =
        Regex("""^\{([^}:]+)(?::(.*))?}$""")

    private val bracketPattern =
        Regex("""\[([^]]+)]""")

    private val chordTokenPattern =
        Regex(
            """^[A-Ga-g](?:#|b|♯|♭)?[A-Za-z0-9#b♯♭()+,\-△Δ°ø]*(?:/[A-Ga-g](?:#|b|♯|♭)?)?$"""
        )

    private val bpmPattern =
        Regex(
            """(?i)\bBPM\s*[=≒~:]?\s*(\d{2,3})\b"""
        )

    fun parse(
        source: String,
        fallbackTitle: String,
        sourceUrl: String
    ): ChordWikiSong {
        var title = fallbackTitle
        var artist = ""
        var key: String? = null
        var bpm: Int? = null

        val lines = buildList {
            source
                .replace("\r\n", "\n")
                .replace('\r', '\n')
                .lineSequence()
                .forEach { rawLine ->
                    val trimmed = rawLine.trim()

                    if (trimmed.startsWith("#")) {
                        return@forEach
                    }

                    val directive =
                        directivePattern.matchEntire(trimmed)

                    if (directive != null) {
                        val name =
                            directive.groupValues[1]
                                .trim()
                                .lowercase()

                        val value =
                            directive.groupValues
                                .getOrElse(2) { "" }
                                .trim()

                        when (name) {
                            "title", "t" -> {
                                if (value.isNotBlank()) {
                                    title = value
                                }
                            }

                            "subtitle", "st", "artist" -> {
                                if (value.isNotBlank()) {
                                    artist = value
                                }
                            }

                            "key" -> {
                                key = value.takeIf {
                                    it.isNotBlank()
                                }
                            }

                            "tempo", "bpm" -> {
                                bpm = value
                                    .toIntOrNull()
                                    ?.takeIf {
                                        it in 20..400
                                    }
                            }

                            "comment", "c",
                            "comment_italic", "ci" -> {
                                if (value.isNotBlank()) {
                                    if (bpm == null) {
                                        bpm =
                                            extractBpm(value)
                                    }

                                    add(
                                        ChordWikiLine(
                                            segments = listOf(
                                                ChordWikiSegment(
                                                    text = value
                                                )
                                            ),
                                            type =
                                                ChordWikiLineType.COMMENT
                                        )
                                    )
                                }
                            }
                        }

                        return@forEach
                    }

                    if (trimmed.isEmpty()) {
                        add(
                            ChordWikiLine(
                                type =
                                    ChordWikiLineType.BLANK
                            )
                        )
                        return@forEach
                    }

                    if (bpm == null) {
                        bpm = extractBpm(rawLine)
                    }

                    add(parseContentLine(rawLine))
                }
        }

        return ChordWikiSong(
            pageTitle = fallbackTitle,
            title = title,
            artist = artist,
            key = key,
            bpm = bpm,
            lines = trimBlankEdges(lines),
            sourceUrl = sourceUrl
        )
    }

    private fun parseContentLine(
        line: String
    ): ChordWikiLine {
        val segments =
            mutableListOf<ChordWikiSegment>()

        var cursor = 0
        var pendingChord: String? = null

        bracketPattern
            .findAll(line)
            .forEach { match ->
                val before =
                    line.substring(
                        cursor,
                        match.range.first
                    )

                if (
                    before.isNotEmpty() ||
                    pendingChord != null
                ) {
                    appendSegment(
                        segments = segments,
                        chord = pendingChord,
                        text = before
                    )
                    pendingChord = null
                }

                val token =
                    match.groupValues[1].trim()

                if (isChordToken(token)) {
                    pendingChord = token
                } else {
                    appendSegment(
                        segments = segments,
                        chord = null,
                        text = "[" + token + "]"
                    )
                }

                cursor = match.range.last + 1
            }

        val tail =
            line.substring(cursor)

        if (
            tail.isNotEmpty() ||
            pendingChord != null
        ) {
            appendSegment(
                segments = segments,
                chord = pendingChord,
                text = tail
            )
        }

        if (segments.isEmpty()) {
            segments +=
                ChordWikiSegment(text = line)
        }

        return ChordWikiLine(
            segments = segments
        )
    }

    private fun appendSegment(
        segments: MutableList<ChordWikiSegment>,
        chord: String?,
        text: String
    ) {
        if (
            chord == null &&
            segments.isNotEmpty() &&
            segments.last().chord == null
        ) {
            val previous = segments.removeAt(
                segments.lastIndex
            )

            segments +=
                previous.copy(
                    text = previous.text + text
                )
        } else {
            segments +=
                ChordWikiSegment(
                    chord = chord,
                    text = text
                )
        }
    }

    private fun isChordToken(
        token: String
    ): Boolean {
        val normalized =
            token
                .trim()
                .replace("♯", "#")
                .replace("♭", "b")

        return normalized == "<" ||
            normalized.equals(
                "N.C.",
                ignoreCase = true
            ) ||
            normalized.equals(
                "NC",
                ignoreCase = true
            ) ||
            chordTokenPattern.matches(normalized)
    }

    private fun extractBpm(
        text: String
    ): Int? =
        bpmPattern
            .find(text)
            ?.groupValues
            ?.getOrNull(1)
            ?.toIntOrNull()
            ?.takeIf {
                it in 20..400
            }

    private fun trimBlankEdges(
        source: List<ChordWikiLine>
    ): List<ChordWikiLine> {
        val first =
            source.indexOfFirst {
                it.type != ChordWikiLineType.BLANK
            }

        if (first < 0) {
            return emptyList()
        }

        val last =
            source.indexOfLast {
                it.type != ChordWikiLineType.BLANK
            }

        return source.subList(
            first,
            last + 1
        )
    }
}
