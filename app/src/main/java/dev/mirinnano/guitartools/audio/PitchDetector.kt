package dev.mirinnano.guitartools.audio

import kotlin.math.min

interface PitchDetector {
    fun detect(samples: FloatArray, sampleRate: Int): Double?
}

/**
 * YIN fundamental-frequency detector.
 *
 * It is deliberately platform independent so it can be unit tested without Android audio APIs.
 */
class YinPitchDetector(
    private val threshold: Double = 0.15,
    private val minFrequencyHz: Double = 55.0,
    private val maxFrequencyHz: Double = 1_200.0
) : PitchDetector {

    init {
        require(threshold in 0.0..1.0)
        require(minFrequencyHz > 0.0)
        require(maxFrequencyHz > minFrequencyHz)
    }

    override fun detect(samples: FloatArray, sampleRate: Int): Double? {
        if (sampleRate <= 0 || samples.size < 64) return null

        val minTau = (sampleRate / maxFrequencyHz).toInt().coerceAtLeast(2)
        val maxTau = min(
            (sampleRate / minFrequencyHz).toInt(),
            samples.size / 2
        )

        if (maxTau <= minTau) return null

        val difference = DoubleArray(maxTau + 1)

        for (tau in 1..maxTau) {
            var sum = 0.0
            val limit = samples.size - tau
            for (i in 0 until limit) {
                val delta = samples[i] - samples[i + tau]
                sum += delta * delta
            }
            difference[tau] = sum
        }

        val cmnd = DoubleArray(maxTau + 1)
        cmnd[0] = 1.0
        var runningSum = 0.0

        for (tau in 1..maxTau) {
            runningSum += difference[tau]
            cmnd[tau] = if (runningSum == 0.0) {
                1.0
            } else {
                difference[tau] * tau / runningSum
            }
        }

        var tauEstimate = -1
        var tau = minTau

        while (tau <= maxTau) {
            if (cmnd[tau] < threshold) {
                while (tau + 1 <= maxTau && cmnd[tau + 1] < cmnd[tau]) {
                    tau++
                }
                tauEstimate = tau
                break
            }
            tau++
        }

        if (tauEstimate == -1) {
            var bestTau = minTau
            for (candidate in (minTau + 1)..maxTau) {
                if (cmnd[candidate] < cmnd[bestTau]) {
                    bestTau = candidate
                }
            }
            if (cmnd[bestTau] > 0.35) return null
            tauEstimate = bestTau
        }

        val refinedTau = parabolicInterpolation(cmnd, tauEstimate)
        if (refinedTau <= 0.0) return null

        val frequency = sampleRate / refinedTau
        return frequency.takeIf { it in minFrequencyHz..maxFrequencyHz }
    }

    private fun parabolicInterpolation(values: DoubleArray, index: Int): Double {
        if (index <= 0 || index >= values.lastIndex) return index.toDouble()

        val left = values[index - 1]
        val center = values[index]
        val right = values[index + 1]
        val denominator = 2.0 * (2.0 * center - right - left)

        if (denominator == 0.0) return index.toDouble()

        return index + (right - left) / denominator
    }
}
