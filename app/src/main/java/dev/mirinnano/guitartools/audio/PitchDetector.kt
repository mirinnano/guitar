package dev.mirinnano.guitartools.audio

interface PitchDetector {
    fun detect(samples: FloatArray, sampleRate: Int): Double?
}

/**
 * Placeholder for a YIN implementation.
 * Keeping the interface separate lets the tuner UI and microphone capture
 * evolve independently from the pitch detection algorithm.
 */
class YinPitchDetector : PitchDetector {
    override fun detect(samples: FloatArray, sampleRate: Int): Double? = null
}
