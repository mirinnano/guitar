package dev.mirinnano.guitartools.music

data class ChordShape(
    val name: String,
    val frets: List<Int>,
    val fingers: List<Int?> = List(6) { null }
)

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
