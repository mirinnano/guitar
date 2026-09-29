package dev.mirinnano.guitartools.music

enum class ChordQuality(
    val symbol: String,
    val displayName: String,
    val intervals: List<Int>
) {
    MAJOR("", "Major", listOf(0, 4, 7)),
    MINOR("m", "Minor", listOf(0, 3, 7)),
    DOMINANT_7("7", "7", listOf(0, 4, 7, 10)),
    MAJOR_7("maj7", "maj7", listOf(0, 4, 7, 11)),
    MINOR_7("m7", "m7", listOf(0, 3, 7, 10))
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
    val chord: Chord,
    val frets: List<Int>,
    val fingers: List<Int?> = List(6) { null },
    val baseFret: Int = 1
) {
    val name: String
        get() = chord.name

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
        shape(Note.C, ChordQuality.MAJOR, listOf(-1, 3, 2, 0, 1, 0), listOf(null, 3, 2, null, 1, null)),
        shape(Note.D, ChordQuality.MAJOR, listOf(-1, -1, 0, 2, 3, 2), listOf(null, null, null, 1, 3, 2)),
        shape(Note.E, ChordQuality.MAJOR, listOf(0, 2, 2, 1, 0, 0), listOf(null, 2, 3, 1, null, null)),
        shape(Note.G, ChordQuality.MAJOR, listOf(3, 2, 0, 0, 0, 3), listOf(2, 1, null, null, null, 3)),
        shape(Note.A, ChordQuality.MAJOR, listOf(-1, 0, 2, 2, 2, 0), listOf(null, null, 1, 2, 3, null)),

        shape(Note.A, ChordQuality.MINOR, listOf(-1, 0, 2, 2, 1, 0), listOf(null, null, 2, 3, 1, null)),
        shape(Note.D, ChordQuality.MINOR, listOf(-1, -1, 0, 2, 3, 1), listOf(null, null, null, 2, 3, 1)),
        shape(Note.E, ChordQuality.MINOR, listOf(0, 2, 2, 0, 0, 0), listOf(null, 2, 3, null, null, null)),

        shape(Note.C, ChordQuality.DOMINANT_7, listOf(-1, 3, 2, 3, 1, 0), listOf(null, 3, 2, 4, 1, null)),
        shape(Note.D, ChordQuality.DOMINANT_7, listOf(-1, -1, 0, 2, 1, 2), listOf(null, null, null, 2, 1, 3)),
        shape(Note.E, ChordQuality.DOMINANT_7, listOf(0, 2, 0, 1, 0, 0), listOf(null, 2, null, 1, null, null)),
        shape(Note.G, ChordQuality.DOMINANT_7, listOf(3, 2, 0, 0, 0, 1), listOf(3, 2, null, null, null, 1)),
        shape(Note.A, ChordQuality.DOMINANT_7, listOf(-1, 0, 2, 0, 2, 0), listOf(null, null, 1, null, 2, null)),
        shape(Note.B, ChordQuality.DOMINANT_7, listOf(-1, 2, 1, 2, 0, 2), listOf(null, 2, 1, 3, null, 4)),

        shape(Note.C, ChordQuality.MAJOR_7, listOf(-1, 3, 2, 0, 0, 0), listOf(null, 3, 2, null, null, null)),
        shape(Note.D, ChordQuality.MAJOR_7, listOf(-1, -1, 0, 2, 2, 2), listOf(null, null, null, 1, 1, 1)),
        shape(Note.E, ChordQuality.MAJOR_7, listOf(0, 2, 1, 1, 0, 0), listOf(null, 2, 1, 1, null, null)),
        shape(Note.G, ChordQuality.MAJOR_7, listOf(3, 2, 0, 0, 0, 2), listOf(3, 2, null, null, null, 1)),
        shape(Note.A, ChordQuality.MAJOR_7, listOf(-1, 0, 2, 1, 2, 0), listOf(null, null, 2, 1, 3, null)),

        shape(Note.A, ChordQuality.MINOR_7, listOf(-1, 0, 2, 0, 1, 0), listOf(null, null, 2, null, 1, null)),
        shape(Note.D, ChordQuality.MINOR_7, listOf(-1, -1, 0, 2, 1, 1), listOf(null, null, null, 2, 1, 1)),
        shape(Note.E, ChordQuality.MINOR_7, listOf(0, 2, 0, 0, 0, 0), listOf(null, 2, null, null, null, null)),
        shape(Note.B, ChordQuality.MINOR_7, listOf(-1, 2, 0, 2, 0, 2), listOf(null, 1, null, 2, null, 3))
    )

    private fun shape(
        root: Note,
        quality: ChordQuality,
        frets: List<Int>,
        fingers: List<Int?>
    ) = ChordShape(
        chord = Chord(root, quality),
        frets = frets,
        fingers = fingers
    )
}
