package dev.mirinnano.guitartools.audio

import dev.mirinnano.guitartools.music.Pitch
import dev.mirinnano.guitartools.music.PitchReading
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

data class TunerConfig(
    val a4Hz: Double = 440.0,
    val minimumRms: Double = 0.008,
    val smoothingWindow: Int = 5
) {
    init {
        require(a4Hz in 400.0..480.0)
        require(minimumRms >= 0.0)
        require(smoothingWindow >= 1 && smoothingWindow % 2 == 1)
    }
}

class TunerEngine(
    private val source: PcmSource,
    private val pitchDetector: PitchDetector = YinPitchDetector()
) : TunerReader {

    override fun readings(
        configProvider: () -> TunerConfig
    ): Flow<PitchReading?> {
        var smoother: MedianFrequencySmoother? = null
        var smootherWindow = -1

        return source.frames().map { frame ->
            val config = configProvider()

            if (smoother == null || smootherWindow != config.smoothingWindow) {
                smoother = MedianFrequencySmoother(config.smoothingWindow)
                smootherWindow = config.smoothingWindow
            }

            if (rms(frame.samples) < config.minimumRms) {
                smoother?.clear()
                return@map null
            }

            val detected = pitchDetector.detect(
                samples = frame.samples,
                sampleRate = frame.sampleRate
            )

            if (detected == null) {
                return@map null
            }

            val smoothed = requireNotNull(smoother).add(detected)

            Pitch.analyze(
                frequencyHz = smoothed,
                a4Hz = config.a4Hz
            )
        }
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
