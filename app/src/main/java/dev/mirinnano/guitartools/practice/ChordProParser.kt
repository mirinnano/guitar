package dev.mirinnano.guitartools.practice

import dev.mirinnano.guitartools.music.normalizeChordLookup

object ChordProParser {

    private val chordPattern =
        Regex("\\[([^]]+)]")

    private val titlePattern =
        Regex(
            "^\\{(?:title|t):\\s*(.+)}$",
            RegexOption.IGNORE_CASE
        )

    private val artistPattern =
        Regex(
            "^\\{(?:subtitle|st|artist):\\s*(.+)}$",
            RegexOption.IGNORE_CASE
        )

    private val bpmPattern =
        Regex(
            "^\\{(?:tempo|bpm):\\s*(\\d+)}$",
            RegexOption.IGNORE_CASE
        )

    fun parse(
        source: String
    ): ChordChart {
        var title = "Imported chart"
        var artist = ""
        var bpm: Int? = null

        val steps =
            buildList {
                source
                    .lineSequence()
                    .forEach { rawLine ->
                        val line =
                            rawLine.trim()

                        titlePattern
                            .matchEntire(line)
                            ?.let {
                                title =
                                    it.groupValues[1]
                                        .trim()
                                return@forEach
                            }

                        artistPattern
                            .matchEntire(line)
                            ?.let {
                                artist =
                                    it.groupValues[1]
                                        .trim()
                                return@forEach
                            }

                        bpmPattern
                            .matchEntire(line)
                            ?.let {
                                bpm =
                                    it.groupValues[1]
                                        .toIntOrNull()
                                return@forEach
                            }

                        chordPattern
                            .findAll(rawLine)
                            .forEach { match ->
                                val symbol =
                                    match.groupValues[1]
                                        .trim()

                                val lookup =
                                    normalizeChordLookup(
                                        symbol
                                    )
                                        ?: return@forEach

                                add(
                                    ProgressionStep(
                                        symbol = symbol,
                                        lookupName =
                                            lookup
                                    )
                                )
                            }
                    }
            }

        return ChordChart(
            title = title,
            artist = artist,
            bpm = bpm,
            steps = steps
        )
    }
}
