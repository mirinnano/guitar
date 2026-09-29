package dev.mirinnano.guitartools.audio

import dev.mirinnano.guitartools.music.Pitch
import dev.mirinnano.guitartools.music.PitchReading
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.mapNotNull

data class TunerConfig(
    val a4Hz: Double = 440.0,
    val minimumRms: Double = 0.008
) {
    init {
        require(a4Hz in 400.0..480.0)
        require(minimumRms >= 0.0)
    }
}

class TunerEngine(
    private val source: PcmSource,
    private val pitchDetector: PitchDetector = YinPitchDetector()
) {
    fun readings(config: TunerConfig = TunerConfig()): Flow<PitchReading> =
        source.frames().mapNotNull { frame ->
            if (rms(frame.samples) < config.minimumRms) {
                return@mapNotNull null
            }

            val frequency = pitchDetector.detect(
                samples = frame.samples,
                sampleRate = frame.sampleRate
            ) ?: return@mapNotNull null

            Pitch.analyze(
                frequencyHz = frequency,
                a4Hz = config.a4Hz
            )
        }

    private fun rms(samples: FloatArray): Double {
        if (samples.isEmpty()) return 0.0

        var sum = 0.0
        for (sample in samples) {
            sum += sample * sample
        }
        return kotlin.math.sqrt(sum / samples.size)
    }
}
