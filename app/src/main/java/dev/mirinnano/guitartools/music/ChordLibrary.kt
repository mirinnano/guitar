package dev.mirinnano.guitartools.music

/**
 * Complete chromatic chord catalogue.
 *
 * Every supported quality is available for every root from C through B.
 * Familiar open-position shapes override the generated movable voicings where
 * they are easier to play.
 */
object CommonChords {

    private data class MovableTemplate(
        val offsets: List<Int>,
        val fingers: List<Int?> = List(6) { null },
        val fullBarre: Boolean = true
    ) {
        init {
            require(offsets.size == 6)
            require(fingers.size == 6)
        }
    }

    private val movableTemplates = mapOf(
        ChordQuality.MAJOR to MovableTemplate(
            offsets = listOf(0, 2, 2, 1, 0, 0),
            fingers = listOf(1, 3, 4, 2, 1, 1)
        ),
        ChordQuality.MINOR to MovableTemplate(
            offsets = listOf(0, 2, 2, 0, 0, 0),
            fingers = listOf(1, 3, 4, 1, 1, 1)
        ),
        ChordQuality.POWER_5 to MovableTemplate(
            offsets = listOf(0, 2, 2, -1, -1, -1),
            fingers = listOf(1, 3, 4, null, null, null),
            fullBarre = false
        ),
        ChordQuality.MAJOR_6 to MovableTemplate(
            offsets = listOf(0, 2, 2, 1, 2, 0),
            fingers = listOf(1, 2, 3, 1, 4, 1)
        ),
        ChordQuality.MINOR_6 to MovableTemplate(
            offsets = listOf(0, 2, 2, 0, 2, 0),
            fingers = listOf(1, 2, 3, 1, 4, 1)
        ),
        ChordQuality.DOMINANT_7 to MovableTemplate(
            offsets = listOf(0, 2, 0, 1, 0, 0),
            fingers = listOf(1, 3, 1, 2, 1, 1)
        ),
        ChordQuality.MAJOR_7 to MovableTemplate(
            offsets = listOf(0, 2, 1, 1, 0, 0),
            fingers = listOf(1, 3, 2, 2, 1, 1)
        ),
        ChordQuality.MINOR_7 to MovableTemplate(
            offsets = listOf(0, 2, 0, 0, 0, 0),
            fingers = listOf(1, 3, 1, 1, 1, 1)
        ),
        ChordQuality.DOMINANT_9 to MovableTemplate(
            offsets = listOf(0, 2, 0, 1, 0, 2),
            fingers = listOf(1, 3, 1, 2, 1, 4)
        ),
        ChordQuality.MAJOR_9 to MovableTemplate(
            offsets = listOf(0, 2, 1, 1, 0, 2),
            fingers = listOf(1, 3, 2, 2, 1, 4)
        ),
        ChordQuality.MINOR_9 to MovableTemplate(
            offsets = listOf(0, 2, 0, 0, 0, 2),
            fingers = listOf(1, 3, 1, 1, 1, 4)
        ),
        ChordQuality.SUS_2 to MovableTemplate(
            offsets = listOf(0, 2, 4, 4, 0, 0),
            fingers = listOf(1, 2, 3, 4, 1, 1)
        ),
        ChordQuality.SUS_4 to MovableTemplate(
            offsets = listOf(0, 2, 2, 2, 0, 0),
            fingers = listOf(1, 3, 3, 3, 1, 1)
        ),
        ChordQuality.ADD_9 to MovableTemplate(
            offsets = listOf(0, 2, 2, 1, 0, 2),
            fingers = listOf(1, 2, 3, 1, 1, 4)
        ),
        ChordQuality.DIMINISHED to MovableTemplate(
            offsets = listOf(0, 1, 2, 0, -1, -1),
            fingers = listOf(1, 2, 4, 3, null, null),
            fullBarre = false
        ),
        ChordQuality.AUGMENTED to MovableTemplate(
            offsets = listOf(0, 3, 2, 1, 1, 0),
            fingers = listOf(1, 4, 3, 2, 2, 1)
        )
    )

    /**
     * Easier/open voicings shown instead of a movable shape when available.
     */
    private val preferredShapes = listOf(
        shape(Note.C, ChordQuality.MAJOR, -1, 3, 2, 0, 1, 0, fingers = listOf(null, 3, 2, null, 1, null)),
        shape(Note.D, ChordQuality.MAJOR, -1, -1, 0, 2, 3, 2, fingers = listOf(null, null, null, 1, 3, 2)),
        shape(Note.E, ChordQuality.MAJOR, 0, 2, 2, 1, 0, 0, fingers = listOf(null, 2, 3, 1, null, null)),
        shape(Note.G, ChordQuality.MAJOR, 3, 2, 0, 0, 0, 3, fingers = listOf(2, 1, null, null, null, 3)),
        shape(Note.A, ChordQuality.MAJOR, -1, 0, 2, 2, 2, 0, fingers = listOf(null, null, 1, 2, 3, null)),

        shape(Note.A, ChordQuality.MINOR, -1, 0, 2, 2, 1, 0, fingers = listOf(null, null, 2, 3, 1, null)),
        shape(Note.D, ChordQuality.MINOR, -1, -1, 0, 2, 3, 1, fingers = listOf(null, null, null, 2, 3, 1)),
        shape(Note.E, ChordQuality.MINOR, 0, 2, 2, 0, 0, 0, fingers = listOf(null, 2, 3, null, null, null)),

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
        shape(Note.B, ChordQuality.MINOR_7, -1, 2, 0, 2, 0, 2, fingers = listOf(null, 1, null, 2, null, 3)),

        shape(Note.D, ChordQuality.SUS_2, -1, -1, 0, 2, 3, 0, fingers = listOf(null, null, null, 1, 2, null)),
        shape(Note.A, ChordQuality.SUS_2, -1, 0, 2, 2, 0, 0, fingers = listOf(null, null, 1, 2, null, null)),
        shape(Note.E, ChordQuality.SUS_2, 0, 2, 4, 4, 0, 0, fingers = listOf(null, 1, 3, 4, null, null)),

        shape(Note.D, ChordQuality.SUS_4, -1, -1, 0, 2, 3, 3, fingers = listOf(null, null, null, 1, 2, 3)),
        shape(Note.A, ChordQuality.SUS_4, -1, 0, 2, 2, 3, 0, fingers = listOf(null, null, 1, 2, 3, null)),
        shape(Note.E, ChordQuality.SUS_4, 0, 2, 2, 2, 0, 0, fingers = listOf(null, 1, 2, 3, null, null)),

        shape(Note.C, ChordQuality.ADD_9, -1, 3, 2, 0, 3, 0, fingers = listOf(null, 2, 1, null, 3, null)),
        shape(Note.G, ChordQuality.ADD_9, 3, 2, 0, 2, 0, 3, fingers = listOf(2, 1, null, 3, null, 4)),
        shape(Note.E, ChordQuality.ADD_9, 0, 2, 2, 1, 0, 2, fingers = listOf(null, 2, 3, 1, null, 4))
    )

    private val generatedShapes: List<ChordShape> =
        Note.entries.flatMap { root ->
            ChordQuality.entries.map { quality ->
                movableShape(root, quality)
            }
        }

    val all: List<ChordShape> = buildList {
        val preferredByName = preferredShapes.associateBy { it.name }

        generatedShapes.forEach { generated ->
            add(preferredByName[generated.name] ?: generated)
        }
    }

    fun forRoot(root: Note): List<ChordShape> =
        all.filter { it.chord.root == root }

    private fun movableShape(
        root: Note,
        quality: ChordQuality
    ): ChordShape {
        val template = requireNotNull(movableTemplates[quality])
        val rootFret = Math.floorMod(
            root.semitoneFromC - Note.E.semitoneFromC,
            12
        )

        val frets = template.offsets.map { offset ->
            if (offset < 0) -1 else rootFret + offset
        }

        val barres = if (
            rootFret > 0 &&
            template.fullBarre
        ) {
            listOf(
                Barre(
                    fret = rootFret,
                    fromString = 6,
                    toString = 1
                )
            )
        } else {
            emptyList()
        }

        return ChordShape(
            chord = Chord(root, quality),
            frets = frets,
            fingers = if (rootFret == 0) {
                template.fingers.mapIndexed { index, finger ->
                    if (frets[index] == 0) null else finger
                }
            } else {
                template.fingers
            },
            barres = barres,
            baseFret = rootFret.coerceAtLeast(1)
        )
    }

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
