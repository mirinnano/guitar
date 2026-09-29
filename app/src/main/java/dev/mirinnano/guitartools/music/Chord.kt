package dev.mirinnano.guitartools.music

enum class ChordQuality(
    val symbol: String,
    val intervals: List<Int>
) {
    MAJOR("", listOf(0, 4, 7)),
    MINOR("m", listOf(0, 3, 7)),
    DOMINANT_7("7", listOf(0, 4, 7, 10)),
    MAJOR_7("maj7", listOf(0, 4, 7, 11)),
    MINOR_7("m7", listOf(0, 3, 7, 10))
}

data class Chord(
    val root: Note,
    val quality: ChordQuality
) {
    val name: String
        get() = root.displayName + quality.symbol

    val notes: List<Note>
        get() = quality.intervals.map { interval ->
            Note.fromMidi(root.semitoneFromC + interval)
        }
}

data class ChordShape(
    val name: String,
    val frets: List<Int>,
    val fingers: List<Int?> = List(6) { null },
    val baseFret: Int = 1
) {
    init {
        require(frets.size == 6) { "A guitar chord shape must contain six strings" }
        require(fingers.size == 6) { "Finger data must contain six strings" }
        require(frets.all { it >= -1 }) {
            "Frets use -1 for mute, 0 for open, or a positive fret"
        }
        require(fingers.all { it == null || it in 1..4 }) {
            "Finger numbers must be 1 through 4"
        }
        require(baseFret >= 1)
    }
}

object CommonChords {
    val all = listOf(
        ChordShape(
            name = "C",
            frets = listOf(-1, 3, 2, 0, 1, 0),
            fingers = listOf(null, 3, 2, null, 1, null)
        ),
        ChordShape(
            name = "D",
            frets = listOf(-1, -1, 0, 2, 3, 2),
            fingers = listOf(null, null, null, 1, 3, 2)
        ),
        ChordShape(
            name = "E",
            frets = listOf(0, 2, 2, 1, 0, 0),
            fingers = listOf(null, 2, 3, 1, null, null)
        ),
        ChordShape(
            name = "G",
            frets = listOf(3, 2, 0, 0, 0, 3),
            fingers = listOf(2, 1, null, null, null, 3)
        ),
        ChordShape(
            name = "A",
            frets = listOf(-1, 0, 2, 2, 2, 0),
            fingers = listOf(null, null, 1, 2, 3, null)
        ),
        ChordShape(
            name = "Am",
            frets = listOf(-1, 0, 2, 2, 1, 0),
            fingers = listOf(null, null, 2, 3, 1, null)
        ),
        ChordShape(
            name = "Em",
            frets = listOf(0, 2, 2, 0, 0, 0),
            fingers = listOf(null, 2, 3, null, null, null)
        ),
        ChordShape(
            name = "Dm",
            frets = listOf(-1, -1, 0, 2, 3, 1),
            fingers = listOf(null, null, null, 2, 3, 1)
        )
    )
}
