package dev.mirinnano.guitartools.audio

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class TunerEngineTest {
    @Test
    fun appliesMedianSmoothingBeforePitchAnalysis() = runTest {
        val frames = listOf(
            PcmFrame(FloatArray(128) { 0.5f }, 48_000),
            PcmFrame(FloatArray(128) { 0.5f }, 48_000),
            PcmFrame(FloatArray(128) { 0.5f }, 48_000)
        )
        val frequencies = ArrayDeque(listOf(440.0, 441.0, 880.0))

        val source = object : PcmSource {
            override fun frames(): Flow<PcmFrame> = frames.asFlow()
        }
        val detector = object : PitchDetector {
            override fun detect(samples: FloatArray, sampleRate: Int): Double =
                frequencies.removeFirst()
        }

        val readings = TunerEngine(source, detector)
            .readings(TunerConfig(smoothingWindow = 3))
            .toList()

        assertEquals(3, readings.size)
        assertEquals(441.0, readings.last().frequencyHz, 0.0001)
    }

    @Test
    fun ignoresFramesBelowNoiseGate() = runTest {
        val source = object : PcmSource {
            override fun frames(): Flow<PcmFrame> = listOf(
                PcmFrame(FloatArray(128) { 0.0001f }, 48_000)
            ).asFlow()
        }
        val detector = object : PitchDetector {
            override fun detect(samples: FloatArray, sampleRate: Int): Double = 440.0
        }

        val readings = TunerEngine(source, detector)
            .readings(TunerConfig(minimumRms = 0.01))
            .toList()

        assertEquals(0, readings.size)
    }
}
