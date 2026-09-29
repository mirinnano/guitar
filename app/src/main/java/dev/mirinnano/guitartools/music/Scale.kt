package dev.mirinnano.guitartools.music

enum class ScaleType(
    val displayName: String,
    val intervals: List<Int>
) {
    MAJOR("Major", listOf(0, 2, 4, 5, 7, 9, 11)),
    NATURAL_MINOR("Minor", listOf(0, 2, 3, 5, 7, 8, 10)),
    MAJOR_PENTATONIC("Major Pentatonic", listOf(0, 2, 4, 7, 9)),
    MINOR_PENTATONIC("Minor Pentatonic", listOf(0, 3, 5, 7, 10)),
    BLUES("Blues", listOf(0, 3, 5, 6, 7, 10)),
    DORIAN("Dorian", listOf(0, 2, 3, 5, 7, 9, 10)),
    MIXOLYDIAN("Mixolydian", listOf(0, 2, 4, 5, 7, 9, 10));

    fun notes(root: Note): Set<Note> =
        intervals.map { interval ->
            Note.entries[
                Math.floorMod(root.semitoneFromC + interval, 12)
            ]
        }.toSet()
}

fun intervalLabel(
    root: Note,
    note: Note
): String =
    when (
        Math.floorMod(
            note.semitoneFromC - root.semitoneFromC,
            12
        )
    ) {
        0 -> "1"
        1 -> "♭2"
        2 -> "2"
        3 -> "♭3"
        4 -> "3"
        5 -> "4"
        6 -> "♭5"
        7 -> "5"
        8 -> "♭6"
        9 -> "6"
        10 -> "♭7"
        else -> "7"
    }
