package dev.mirinnano.guitartools.music

import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.roundToInt

enum class Note(val semitoneFromC: Int, val displayName: String) {
    C(0, "C"),
    C_SHARP(1, "C#"),
    D(2, "D"),
    D_SHARP(3, "D#"),
    E(4, "E"),
    F(5, "F"),
    F_SHARP(6, "F#"),
    G(7, "G"),
    G_SHARP(8, "G#"),
    A(9, "A"),
    A_SHARP(10, "A#"),
    B(11, "B");

    companion object {
        fun fromMidi(midi: Int): Note = entries[((midi % 12) + 12) % 12]

        fun nearestMidi(frequencyHz: Double, a4Hz: Double = 440.0): Int =
            (69 + 12 * (ln(frequencyHz / a4Hz) / ln(2.0))).roundToInt()

        fun frequencyForMidi(midi: Int, a4Hz: Double = 440.0): Double =
            a4Hz * 2.0.pow((midi - 69) / 12.0)
    }
}

data class PitchedNote(
    val note: Note,
    val octave: Int,
    val midi: Int,
    val frequencyHz: Double
)
