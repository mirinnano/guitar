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
    val accidentalPreference:
        AccidentalPreference =
        AccidentalPreference.SHARPS
) {
    init {
        require(strings.size == 6) {
            "Guitar tuning must contain six strings"
        }
        require(
            strings.map { it.stringNumber }.toSet() ==
                setOf(1, 2, 3, 4, 5, 6)
        ) {
            "String numbers must be 1 through 6"
        }
    }

    fun closestString(
        frequencyHz: Double,
        a4Hz: Double = 440.0
    ): TuningTarget? {
        if (
            frequencyHz <= 0.0 ||
            a4Hz <= 0.0
        ) {
            return null
        }

        return strings
            .mapNotNull { string ->
                targetForString(
                    stringNumber =
                        string.stringNumber,
                    frequencyHz =
                        frequencyHz,
                    a4Hz = a4Hz
                )
            }
            .minByOrNull {
                abs(it.centsFromTarget)
            }
    }

    fun targetForString(
        stringNumber: Int,
        frequencyHz: Double,
        a4Hz: Double = 440.0
    ): TuningTarget? {
        if (
            frequencyHz <= 0.0 ||
            a4Hz <= 0.0
        ) {
            return null
        }

        val string = strings.firstOrNull {
            it.stringNumber == stringNumber
        } ?: return null

        val targetFrequency =
            Note.frequencyForMidi(
                string.midi,
                a4Hz
            )

        val cents =
            1200.0 *
                (
                    ln(
                        frequencyHz /
                            targetFrequency
                    ) / ln(2.0)
                )

        return TuningTarget(
            string = string,
            targetFrequencyHz =
                targetFrequency,
            centsFromTarget = cents
        )
    }

    fun withStringMidi(
        stringNumber: Int,
        midi: Int
    ): Tuning {
        val safeMidi = midi.coerceIn(24, 84)

        val updated = strings.map { string ->
            if (
                string.stringNumber !=
                stringNumber
            ) {
                string
            } else {
                val note =
                    Note.fromMidi(safeMidi)
                val octave =
                    Note.octaveForMidi(
                        safeMidi
                    )

                string.copy(
                    midi = safeMidi,
                    label =
                        note.displayName(
                            accidentalPreference
                        ) + octave
                )
            }
        }

        return copy(
            id = "custom",
            name = "Custom",
            strings = updated
        )
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

        val DropCSharp = Tuning(
            id = "drop_c_sharp",
            name = "Drop C#",
            strings = listOf(
                StringTuning(6, 37, "C#2"),
                StringTuning(5, 44, "G#2"),
                StringTuning(4, 49, "C#3"),
                StringTuning(3, 54, "F#3"),
                StringTuning(2, 58, "A#3"),
                StringTuning(1, 63, "D#4")
            )
        )

        val DropC = Tuning(
            id = "drop_c",
            name = "Drop C",
            strings = listOf(
                StringTuning(6, 36, "C2"),
                StringTuning(5, 43, "G2"),
                StringTuning(4, 48, "C3"),
                StringTuning(3, 53, "F3"),
                StringTuning(2, 57, "A3"),
                StringTuning(1, 62, "D4")
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
            accidentalPreference =
                AccidentalPreference.FLATS
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

        val OpenG = Tuning(
            id = "open_g",
            name = "Open G",
            strings = listOf(
                StringTuning(6, 38, "D2"),
                StringTuning(5, 43, "G2"),
                StringTuning(4, 50, "D3"),
                StringTuning(3, 55, "G3"),
                StringTuning(2, 59, "B3"),
                StringTuning(1, 62, "D4")
            )
        )

        val Dadgad = Tuning(
            id = "dadgad",
            name = "DADGAD",
            strings = listOf(
                StringTuning(6, 38, "D2"),
                StringTuning(5, 45, "A2"),
                StringTuning(4, 50, "D3"),
                StringTuning(3, 55, "G3"),
                StringTuning(2, 57, "A3"),
                StringTuning(1, 62, "D4")
            )
        )

        val CustomDefault = Standard.copy(
            id = "custom",
            name = "Custom"
        )

        val Presets = listOf(
            Standard,
            DropD,
            DropCSharp,
            DropC,
            EbStandard,
            DStandard,
            OpenG,
            Dadgad
        )
    }
}
