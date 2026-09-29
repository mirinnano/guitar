package dev.mirinnano.guitartools.music

data class FretPosition(
    val stringNumber: Int,
    val fret: Int,
    val midi: Int,
    val note: Note,
    val octave: Int
)

object Fretboard {
    const val DEFAULT_MAX_FRET = 24

    fun position(
        string: StringTuning,
        fret: Int
    ): FretPosition {
        require(fret >= 0) { "fret must be non-negative" }

        val midi = string.midi + fret
        return FretPosition(
            stringNumber = string.stringNumber,
            fret = fret,
            midi = midi,
            note = Note.fromMidi(midi),
            octave = Note.octaveForMidi(midi)
        )
    }

    fun positions(
        tuning: Tuning = Tuning.Standard,
        maxFret: Int = DEFAULT_MAX_FRET
    ): List<FretPosition> {
        require(maxFret >= 0)
        return tuning.strings.flatMap { string ->
            (0..maxFret).map { fret -> position(string, fret) }
        }
    }

    fun findNote(
        note: Note,
        tuning: Tuning = Tuning.Standard,
        maxFret: Int = DEFAULT_MAX_FRET
    ): List<FretPosition> =
        positions(tuning, maxFret).filter { it.note == note }
}
