package dev.mirinnano.guitartools.chordwiki

import kotlin.math.floor

data class TimedChordEvent(
    val symbol: String,
    val lineIndex: Int,
    val segmentIndex: Int,
    val startBeat: Float,
    val durationBeats: Float
) {
    val endBeat: Float
        get() = startBeat + durationBeats
}

data class TimedChartLine(
    val lineIndex: Int,
    val startBeat: Float,
    val durationBeats: Float
) {
    val endBeat: Float
        get() = startBeat + durationBeats
}

data class ChordTimeline(
    val beatsPerBar: Int,
    val totalBeats: Float,
    val events: List<TimedChordEvent>,
    val lines: List<TimedChartLine>
) {
    fun activeEvent(
        beat: Float
    ): TimedChordEvent? {
        if (events.isEmpty()) return null

        val clamped =
            beat.coerceIn(
                0f,
                totalBeats.coerceAtLeast(0f)
            )

        return events
            .lastOrNull {
                clamped >= it.startBeat
            }
            ?.takeIf {
                clamped < it.endBeat ||
                    it == events.last()
            }
    }

    fun activeLine(
        beat: Float
    ): TimedChartLine? {
        if (lines.isEmpty()) return null

        val clamped =
            beat.coerceIn(
                0f,
                totalBeats.coerceAtLeast(0f)
            )

        return lines
            .lastOrNull {
                clamped >= it.startBeat
            }
            ?: lines.firstOrNull()
    }

    fun lineProgress(
        line: TimedChartLine,
        beat: Float
    ): Float {
        if (line.durationBeats <= 0f) {
            return 0f
        }

        return (
            (beat - line.startBeat) /
                line.durationBeats
            ).coerceIn(0f, 1f)
    }

    fun durationMs(
        bpm: Int
    ): Long {
        if (bpm <= 0 || totalBeats <= 0f) {
            return 0L
        }

        return (
            totalBeats *
                60_000f /
                bpm
            ).toLong()
    }

    fun beatForPositionMs(
        positionMs: Long,
        bpm: Int
    ): Float {
        if (bpm <= 0) return 0f

        return (
            positionMs
                .coerceAtLeast(0L)
                .toFloat() *
                bpm /
                60_000f
            ).coerceIn(
            0f,
            totalBeats.coerceAtLeast(0f)
        )
    }

    fun positionMsForBeat(
        beat: Float,
        bpm: Int
    ): Long {
        if (bpm <= 0) return 0L

        return (
            beat.coerceIn(
                0f,
                totalBeats.coerceAtLeast(0f)
            ) *
                60_000f /
                bpm
            ).toLong()
    }

    fun barNumber(
        beat: Float
    ): Int =
        if (beatsPerBar <= 0) {
            1
        } else {
            floor(
                beat.coerceAtLeast(0f) /
                    beatsPerBar
            ).toInt() + 1
        }
}

object ChordTimelineBuilder {

    private val barPattern =
        Regex("""[|｜]+(?::|：)?|(?::|：)[|｜]+""")

    fun build(
        song: ChordWikiSong,
        beatsPerBar: Int =
            song.beatsPerBar
                ?.coerceIn(1, 12)
                ?: 4
    ): ChordTimeline {
        var beatCursor = 0f
        val events =
            mutableListOf<TimedChordEvent>()
        val lines =
            mutableListOf<TimedChartLine>()

        song.lines.forEachIndexed {
                lineIndex,
                line ->

            if (
                line.type !=
                ChordWikiLineType.CONTENT
            ) {
                return@forEachIndexed
            }

            val chordSegments =
                line.segments
                    .mapIndexedNotNull {
                            segmentIndex,
                            segment ->
                        segment.chord
                            ?.let {
                                segmentIndex to it
                            }
                    }

            val hasVisibleText =
                line.segments.any {
                    it.text
                        .replace(barPattern, "")
                        .isNotBlank()
                }

            if (
                chordSegments.isEmpty() &&
                !hasVisibleText
            ) {
                return@forEachIndexed
            }

            val groups =
                splitIntoBars(line)

            val effectiveGroups =
                if (groups.isEmpty()) {
                    listOf(emptyList())
                } else {
                    groups
                }

            val lineStart =
                beatCursor

            effectiveGroups.forEach { group ->
                val barStart =
                    beatCursor

                if (group.isNotEmpty()) {
                    val chordDuration =
                        beatsPerBar.toFloat() /
                            group.size

                    group.forEachIndexed {
                            index,
                            chord ->
                        events +=
                            TimedChordEvent(
                                symbol =
                                    chord.second,
                                lineIndex =
                                    lineIndex,
                                segmentIndex =
                                    chord.first,
                                startBeat =
                                    barStart +
                                        chordDuration *
                                        index,
                                durationBeats =
                                    chordDuration
                            )
                    }
                }

                beatCursor +=
                    beatsPerBar.toFloat()
            }

            lines +=
                TimedChartLine(
                    lineIndex = lineIndex,
                    startBeat = lineStart,
                    durationBeats =
                        beatCursor - lineStart
                )
        }

        return ChordTimeline(
            beatsPerBar = beatsPerBar,
            totalBeats = beatCursor,
            events = events,
            lines = lines
        )
    }

    private fun splitIntoBars(
        line: ChordWikiLine
    ): List<List<Pair<Int, String>>> {
        val groups =
            mutableListOf<List<Pair<Int, String>>>()
        val current =
            mutableListOf<Pair<Int, String>>()
        var sawBar = false

        line.segments.forEachIndexed {
                segmentIndex,
                segment ->

            segment.chord?.let {
                current +=
                    segmentIndex to it
            }

            val barCount =
                barPattern
                    .findAll(segment.text)
                    .count()

            if (barCount > 0) {
                sawBar = true

                repeat(barCount) {
                    groups += current.toList()
                    current.clear()
                }
            }
        }

        if (
            current.isNotEmpty() ||
            !sawBar
        ) {
            groups += current.toList()
        }

        while (
            groups.size > 1 &&
            groups.last().isEmpty()
        ) {
            groups.removeAt(
                groups.lastIndex
            )
        }

        return groups
    }
}
