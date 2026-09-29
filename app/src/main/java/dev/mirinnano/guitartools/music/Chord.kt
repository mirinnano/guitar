package dev.mirinnano.guitartools.music

/**
 * Chord qualities supported by Guitar Tools.
 *
 * intervals are semitone offsets from the root note.
 */
enum class ChordQuality(
    val symbol: String,
    val intervals: List<Int>
) {
    MAJOR("", listOf(0, 4, 7)),
    MINOR("m", listOf(0, 3, 7)),
    POWER_5("5", listOf(0, 7)),
    MAJOR_6("6", listOf(0, 4, 7, 9)),
    MINOR_6("m6", listOf(0, 3, 7, 9)),
    DOMINANT_7("7", listOf(0, 4, 7, 10)),
    MAJOR_7("maj7", listOf(0, 4, 7, 11)),
    MINOR_7("m7", listOf(0, 3, 7, 10)),
    DOMINANT_9("9", listOf(0, 4, 7, 10, 14)),
    MAJOR_9("maj9", listOf(0, 4, 7, 11, 14)),
    MINOR_9("m9", listOf(0, 3, 7, 10, 14)),
    SUS_2("sus2", listOf(0, 2, 7)),
    SUS_4("sus4", listOf(0, 5, 7)),
    ADD_9("add9", listOf(0, 4, 7, 14)),
    DIMINISHED("dim", listOf(0, 3, 6)),
    AUGMENTED("aug", listOf(0, 4, 8))
}

data class Chord(
    val root: Note,
    val quality: ChordQuality
) {
    val name: String
        get() = root.displayName + quality.symbol

    val notes: List<Note>
        get() = quality.intervals
            .map { interval ->
                Note.fromMidi(root.semitoneFromC + interval)
            }
            .distinct()
}

/**
 * One finger laid across several strings.
 *
 * Guitar string numbers are used directly:
 * 6 = low E, 1 = high E.
 */
data class Barre(
    val fret: Int,
    val fromString: Int,
    val toString: Int,
    val finger: Int = 1
) {
    init {
        require(fret > 0)
        require(fromString in 1..6)
        require(toString in 1..6)
        require(fromString >= toString)
        require(finger in 1..4)
    }
}

/**
 * A playable six-string guitar voicing.
 *
 * frets are ordered from string 6 (low E) to string 1 (high E):
 * -1 = mute, 0 = open, positive number = fret.
 */
data class ChordShape(
    val chord: Chord,
    val frets: List<Int>,
    val fingers: List<Int?> = List(6) { null },
    val barres: List<Barre> = emptyList(),
    val baseFret: Int = 1
) {
    val name: String
        get() = chord.name

    init {
        require(frets.size == 6) {
            "A guitar chord shape must contain six strings"
        }
        require(fingers.size == 6) {
            "Finger data must contain six strings"
        }
        require(frets.all { it >= -1 }) {
            "Frets use -1 for mute, 0 for open, or a positive fret"
        }
        require(fingers.all { it == null || it in 1..4 }) {
            "Finger numbers must be 1 through 4"
        }
        require(baseFret >= 1)
    }
}
