package dev.mirinnano.guitartools.music

import kotlin.math.abs
import kotlin.math.ln

data class StringTuning(
    val stringNumber: Int,
    val midi: Int,
    val label: String
)

data class TuningTarget(
    val string: StringTuning,
    val targetFrequencyHz: Double,
    val centsFromTarget: Double
)

data class Tuning(
    val id: String,
    val name: String,
    val strings: List<StringTuning>,
    val accidentalPreference: AccidentalPreference = AccidentalPreference.SHARPS
) {
    init {
        require(strings.size == 6) { "Guitar tuning must contain six strings" }
        require(strings.map { it.stringNumber }.toSet() == setOf(1, 2, 3, 4, 5, 6)) {
            "String numbers must be 1 through 6"
        }
    }

    fun closestString(
        frequencyHz: Double,
        a4Hz: Double = 440.0
    ): TuningTarget? {
        if (frequencyHz <= 0.0 || a4Hz <= 0.0) return null

        return strings
            .map { string ->
                val targetFrequency = Note.frequencyForMidi(string.midi, a4Hz)
                val cents = 1200.0 * (ln(frequencyHz / targetFrequency) / ln(2.0))

                TuningTarget(
                    string = string,
                    targetFrequencyHz = targetFrequency,
                    centsFromTarget = cents
                )
            }
            .minByOrNull { abs(it.centsFromTarget) }
    }

    companion object {
        val Standard = Tuning(
            id = "standard",
            name = "Standard",
            strings = listOf(
                StringTuning(6, 40, "E2"),
                StringTuning(5, 45, "A2"),
                StringTuning(4, 50, "D3"),
                StringTuning(3, 55, "G3"),
                StringTuning(2, 59, "B3"),
                StringTuning(1, 64, "E4")
            )
        )

        val DropD = Tuning(
            id = "drop_d",
            name = "Drop D",
            strings = listOf(
                StringTuning(6, 38, "D2"),
                StringTuning(5, 45, "A2"),
                StringTuning(4, 50, "D3"),
                StringTuning(3, 55, "G3"),
                StringTuning(2, 59, "B3"),
                StringTuning(1, 64, "E4")
            )
        )

        val EbStandard = Tuning(
            id = "eb_standard",
            name = "E♭ Standard",
            strings = listOf(
                StringTuning(6, 39, "E♭2"),
                StringTuning(5, 44, "A♭2"),
                StringTuning(4, 49, "D♭3"),
                StringTuning(3, 54, "G♭3"),
                StringTuning(2, 58, "B♭3"),
                StringTuning(1, 63, "E♭4")
            ),
            accidentalPreference = AccidentalPreference.FLATS
        )

        val DStandard = Tuning(
            id = "d_standard",
            name = "D Standard",
            strings = listOf(
                StringTuning(6, 38, "D2"),
                StringTuning(5, 43, "G2"),
                StringTuning(4, 48, "C3"),
                StringTuning(3, 53, "F3"),
                StringTuning(2, 57, "A3"),
                StringTuning(1, 62, "D4")
            )
        )

        val Presets = listOf(
            Standard,
            DropD,
            EbStandard,
            DStandard
        )
    }
}
