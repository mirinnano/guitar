package dev.mirinnano.guitartools.music

import kotlin.math.ln

data class PitchReading(
    val frequencyHz: Double,
    val midi: Int,
    val note: Note,
    val octave: Int,
    val cents: Double
)

object Pitch {
    fun analyze(frequencyHz: Double, a4Hz: Double = 440.0): PitchReading {
        val midi = Note.nearestMidi(frequencyHz, a4Hz)
        val target = Note.frequencyForMidi(midi, a4Hz)
        val cents = 1200.0 * (ln(frequencyHz / target) / ln(2.0))

        return PitchReading(
            frequencyHz = frequencyHz,
            midi = midi,
            note = Note.fromMidi(midi),
            octave = Note.octaveForMidi(midi),
            cents = cents
        )
    }
}
