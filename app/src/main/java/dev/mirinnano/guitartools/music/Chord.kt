package dev.mirinnano.guitartools.music

/**
 * Chord qualities supported by the built-in chord library.
 *
 * `intervals` are semitone offsets from the root note.
 */
enum class ChordQuality(
    val symbol: String,
    val intervals: List<Int>
) {
    MAJOR("", listOf(0, 4, 7)),
    MINOR("m", listOf(0, 3, 7)),
    POWER_5("5", listOf(0, 7)),
    DOMINANT_7("7", listOf(0, 4, 7, 10)),
    MAJOR_7("maj7", listOf(0, 4, 7, 11)),
    MINOR_7("m7", listOf(0, 3, 7, 10)),
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
        get() = quality.intervals.map { interval ->
            Note.fromMidi(root.semitoneFromC + interval)
        }
}

/**
 * One index-finger barre on a chord diagram.
 *
 * Strings use normal guitar numbering:
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

object CommonChords {

    /**
     * Familiar open-position shapes for beginners.
     */
    private val openChords = listOf(
        shape(Note.C, ChordQuality.MAJOR, -1, 3, 2, 0, 1, 0, fingers = listOf(null, 3, 2, null, 1, null)),
        shape(Note.D, ChordQuality.MAJOR, -1, -1, 0, 2, 3, 2, fingers = listOf(null, null, null, 1, 3, 2)),
        shape(Note.E, ChordQuality.MAJOR, 0, 2, 2, 1, 0, 0, fingers = listOf(null, 2, 3, 1, null, null)),
        shape(Note.G, ChordQuality.MAJOR, 3, 2, 0, 0, 0, 3, fingers = listOf(2, 1, null, null, null, 3)),
        shape(Note.A, ChordQuality.MAJOR, -1, 0, 2, 2, 2, 0, fingers = listOf(null, null, 1, 2, 3, null)),

        shape(Note.A, ChordQuality.MINOR, -1, 0, 2, 2, 1, 0, fingers = listOf(null, null, 2, 3, 1, null)),
        shape(Note.D, ChordQuality.MINOR, -1, -1, 0, 2, 3, 1, fingers = listOf(null, null, null, 2, 3, 1)),
        shape(Note.E, ChordQuality.MINOR, 0, 2, 2, 0, 0, 0, fingers = listOf(null, 2, 3, null, null, null))
    )

    /**
     * Common seventh chords.
     */
    private val seventhChords = listOf(
        shape(Note.C, ChordQuality.DOMINANT_7, -1, 3, 2, 3, 1, 0, fingers = listOf(null, 3, 2, 4, 1, null)),
        shape(Note.D, ChordQuality.DOMINANT_7, -1, -1, 0, 2, 1, 2, fingers = listOf(null, null, null, 2, 1, 3)),
        shape(Note.E, ChordQuality.DOMINANT_7, 0, 2, 0, 1, 0, 0, fingers = listOf(null, 2, null, 1, null, null)),
        shape(Note.G, ChordQuality.DOMINANT_7, 3, 2, 0, 0, 0, 1, fingers = listOf(3, 2, null, null, null, 1)),
        shape(Note.A, ChordQuality.DOMINANT_7, -1, 0, 2, 0, 2, 0, fingers = listOf(null, null, 1, null, 2, null)),
        shape(Note.B, ChordQuality.DOMINANT_7, -1, 2, 1, 2, 0, 2, fingers = listOf(null, 2, 1, 3, null, 4)),

        shape(Note.C, ChordQuality.MAJOR_7, -1, 3, 2, 0, 0, 0, fingers = listOf(null, 3, 2, null, null, null)),
        shape(Note.D, ChordQuality.MAJOR_7, -1, -1, 0, 2, 2, 2, fingers = listOf(null, null, null, 1, 1, 1)),
        shape(Note.E, ChordQuality.MAJOR_7, 0, 2, 1, 1, 0, 0, fingers = listOf(null, 2, 1, 1, null, null)),
        shape(Note.G, ChordQuality.MAJOR_7, 3, 2, 0, 0, 0, 2, fingers = listOf(3, 2, null, null, null, 1)),
        shape(Note.A, ChordQuality.MAJOR_7, -1, 0, 2, 1, 2, 0, fingers = listOf(null, null, 2, 1, 3, null)),

        shape(Note.A, ChordQuality.MINOR_7, -1, 0, 2, 0, 1, 0, fingers = listOf(null, null, 2, null, 1, null)),
        shape(Note.D, ChordQuality.MINOR_7, -1, -1, 0, 2, 1, 1, fingers = listOf(null, null, null, 2, 1, 1)),
        shape(Note.E, ChordQuality.MINOR_7, 0, 2, 0, 0, 0, 0, fingers = listOf(null, 2, null, null, null, null)),
        shape(Note.B, ChordQuality.MINOR_7, -1, 2, 0, 2, 0, 2, fingers = listOf(null, 1, null, 2, null, 3))
    )

    /**
     * Suspended and color chords commonly found in pop/rock.
     */
    private val colorChords = listOf(
        shape(Note.D, ChordQuality.SUS_2, -1, -1, 0, 2, 3, 0, fingers = listOf(null, null, null, 1, 2, null)),
        shape(Note.A, ChordQuality.SUS_2, -1, 0, 2, 2, 0, 0, fingers = listOf(null, null, 1, 2, null, null)),
        shape(Note.E, ChordQuality.SUS_2, 0, 2, 4, 4, 0, 0, fingers = listOf(null, 1, 3, 4, null, null)),

        shape(Note.D, ChordQuality.SUS_4, -1, -1, 0, 2, 3, 3, fingers = listOf(null, null, null, 1, 2, 3)),
        shape(Note.A, ChordQuality.SUS_4, -1, 0, 2, 2, 3, 0, fingers = listOf(null, null, 1, 2, 3, null)),
        shape(Note.E, ChordQuality.SUS_4, 0, 2, 2, 2, 0, 0, fingers = listOf(null, 1, 2, 3, null, null)),

        shape(Note.C, ChordQuality.ADD_9, -1, 3, 2, 0, 3, 0, fingers = listOf(null, 2, 1, null, 3, null)),
        shape(Note.G, ChordQuality.ADD_9, 3, 2, 0, 2, 0, 3, fingers = listOf(2, 1, null, 3, null, 4)),
        shape(Note.E, ChordQuality.ADD_9, 0, 2, 2, 1, 0, 2, fingers = listOf(null, 2, 3, 1, null, 4)),

        shape(Note.B, ChordQuality.DIMINISHED, -1, 2, 3, 1, 3, -1, fingers = listOf(null, 2, 3, 1, 4, null)),
        shape(Note.E, ChordQuality.DIMINISHED, 0, 1, 2, 0, 2, 0, fingers = listOf(null, 1, 2, null, 3, null)),

        shape(Note.C, ChordQuality.AUGMENTED, -1, 3, 2, 1, 1, 0, fingers = listOf(null, 4, 3, 1, 1, null)),
        shape(Note.E, ChordQuality.AUGMENTED, 0, 3, 2, 1, 1, 0, fingers = listOf(null, 4, 3, 1, 1, null))
    )

    /**
     * Barre shapes worth learning after the open chords.
     */
    private val barreChords = listOf(
        shape(
            Note.F,
            ChordQuality.MAJOR,
            1, 3, 3, 2, 1, 1,
            fingers = listOf(1, 3, 4, 2, 1, 1),
            barres = listOf(Barre(1, 6, 1))
        ),
        shape(
            Note.F_SHARP,
            ChordQuality.MINOR,
            2, 4, 4, 2, 2, 2,
            fingers = listOf(1, 3, 4, 1, 1, 1),
            barres = listOf(Barre(2, 6, 1))
        ),
        shape(
            Note.G,
            ChordQuality.MINOR,
            3, 5, 5, 3, 3, 3,
            fingers = listOf(1, 3, 4, 1, 1, 1),
            barres = listOf(Barre(3, 6, 1))
        ),
        shape(
            Note.B,
            ChordQuality.MINOR,
            -1, 2, 4, 4, 3, 2,
            fingers = listOf(null, 1, 3, 4, 2, 1),
            barres = listOf(Barre(2, 5, 1))
        ),
        shape(
            Note.C,
            ChordQuality.MINOR,
            -1, 3, 5, 5, 4, 3,
            fingers = listOf(null, 1, 3, 4, 2, 1),
            barres = listOf(Barre(3, 5, 1))
        )
    )

    /**
     * Easy movable power-chord shapes.
     */
    private val powerChords = listOf(
        shape(Note.E, ChordQuality.POWER_5, 0, 2, 2, -1, -1, -1, fingers = listOf(null, 1, 1, null, null, null)),
        shape(Note.F, ChordQuality.POWER_5, 1, 3, 3, -1, -1, -1, fingers = listOf(1, 3, 4, null, null, null)),
        shape(Note.G, ChordQuality.POWER_5, 3, 5, 5, -1, -1, -1, fingers = listOf(1, 3, 4, null, null, null)),
        shape(Note.A, ChordQuality.POWER_5, -1, 0, 2, 2, -1, -1, fingers = listOf(null, null, 1, 1, null, null)),
        shape(Note.B, ChordQuality.POWER_5, -1, 2, 4, 4, -1, -1, fingers = listOf(null, 1, 3, 4, null, null))
    )

    val all: List<ChordShape> =
        openChords +
            seventhChords +
            colorChords +
            barreChords +
            powerChords

    private fun shape(
        root: Note,
        quality: ChordQuality,
        vararg frets: Int,
        fingers: List<Int?>,
        barres: List<Barre> = emptyList(),
        baseFret: Int = 1
    ) = ChordShape(
        chord = Chord(root, quality),
        frets = frets.toList(),
        fingers = fingers,
        barres = barres,
        baseFret = baseFret
    )
}
