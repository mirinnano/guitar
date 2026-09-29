package dev.mirinnano.guitartools.music

/**
 * Hand-authored, playable guitar shapes.
 *
 * To add a new chord:
 * 1. Pick the root and ChordQuality.
 * 2. Enter six frets from low E to high E.
 * 3. Add optional finger numbers and barres.
 */
object CommonChords {

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

    private val barreChords = listOf(
        shape(
            Note.F, ChordQuality.MAJOR,
            1, 3, 3, 2, 1, 1,
            fingers = listOf(1, 3, 4, 2, 1, 1),
            barres = listOf(Barre(1, 6, 1))
        ),
        shape(
            Note.F_SHARP, ChordQuality.MINOR,
            2, 4, 4, 2, 2, 2,
            fingers = listOf(1, 3, 4, 1, 1, 1),
            barres = listOf(Barre(2, 6, 1))
        ),
        shape(
            Note.G, ChordQuality.MINOR,
            3, 5, 5, 3, 3, 3,
            fingers = listOf(1, 3, 4, 1, 1, 1),
            barres = listOf(Barre(3, 6, 1))
        ),
        shape(
            Note.B, ChordQuality.MINOR,
            -1, 2, 4, 4, 3, 2,
            fingers = listOf(null, 1, 3, 4, 2, 1),
            barres = listOf(Barre(2, 5, 1))
        ),
        shape(
            Note.C, ChordQuality.MINOR,
            -1, 3, 5, 5, 4, 3,
            fingers = listOf(null, 1, 3, 4, 2, 1),
            barres = listOf(Barre(3, 5, 1))
        )
    )

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
