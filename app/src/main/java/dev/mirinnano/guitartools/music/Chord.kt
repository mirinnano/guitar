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
    val fingers: List<Int?> = List(6) { null }
) {
    init {
        require(frets.size == 6) { "A guitar chord shape must contain six strings" }
        require(fingers.size == 6) { "Finger data must contain six strings" }
        require(frets.all { it >= -1 }) { "Frets use -1 for mute, 0 for open, or a positive fret" }
    }
}

object CommonChords {
    val all = listOf(
        ChordShape("C", listOf(-1, 3, 2, 0, 1, 0)),
        ChordShape("D", listOf(-1, -1, 0, 2, 3, 2)),
        ChordShape("E", listOf(0, 2, 2, 1, 0, 0)),
        ChordShape("G", listOf(3, 2, 0, 0, 0, 3)),
        ChordShape("A", listOf(-1, 0, 2, 2, 2, 0)),
        ChordShape("Am", listOf(-1, 0, 2, 2, 1, 0)),
        ChordShape("Em", listOf(0, 2, 2, 0, 0, 0)),
        ChordShape("Dm", listOf(-1, -1, 0, 2, 3, 1))
    )
}
