package dev.mirinnano.guitartools.music

import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.roundToInt

enum class AccidentalPreference {
    SHARPS,
    FLATS
}

enum class Note(
    val semitoneFromC: Int,
    private val sharpName: String,
    private val flatName: String = sharpName
) {
    C(0, "C"),
    C_SHARP(1, "C#", "Db"),
    D(2, "D"),
    D_SHARP(3, "D#", "Eb"),
    E(4, "E"),
    F(5, "F"),
    F_SHARP(6, "F#", "Gb"),
    G(7, "G"),
    G_SHARP(8, "G#", "Ab"),
    A(9, "A"),
    A_SHARP(10, "A#", "Bb"),
    B(11, "B");

    val displayName: String
        get() = sharpName

    fun displayName(preference: AccidentalPreference): String =
        if (preference == AccidentalPreference.FLATS) flatName else sharpName

    companion object {
        fun fromMidi(midi: Int): Note = entries[Math.floorMod(midi, 12)]

        fun octaveForMidi(midi: Int): Int = Math.floorDiv(midi, 12) - 1

        fun nearestMidi(frequencyHz: Double, a4Hz: Double = 440.0): Int {
            require(frequencyHz > 0.0) { "frequencyHz must be positive" }
            require(a4Hz > 0.0) { "a4Hz must be positive" }
            return (69 + 12 * (ln(frequencyHz / a4Hz) / ln(2.0))).roundToInt()
        }

        fun frequencyForMidi(midi: Int, a4Hz: Double = 440.0): Double {
            require(a4Hz > 0.0) { "a4Hz must be positive" }
            return a4Hz * 2.0.pow((midi - 69) / 12.0)
        }
    }
}

data class PitchedNote(
    val note: Note,
    val octave: Int,
    val midi: Int,
    val frequencyHz: Double
)
