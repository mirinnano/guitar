package dev.mirinnano.guitartools.audio

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asFlow
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
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
            .readings { TunerConfig(smoothingWindow = 3) }
            .toList()

        assertEquals(3, readings.size)
        assertEquals(441.0, readings.last()?.frequencyHz ?: 0.0, 0.0001)
    }

    @Test
    fun emitsNoSignalBelowNoiseGate() = runTest {
        val source = object : PcmSource {
            override fun frames(): Flow<PcmFrame> = listOf(
                PcmFrame(FloatArray(128) { 0.0001f }, 48_000)
            ).asFlow()
        }
        val detector = object : PitchDetector {
            override fun detect(samples: FloatArray, sampleRate: Int): Double = 440.0
        }

        val readings = TunerEngine(source, detector)
            .readings { TunerConfig(minimumRms = 0.01) }
            .toList()

        assertEquals(1, readings.size)
        assertNull(readings.single())
    }

    @Test
    fun readsUpdatedReferencePitchWithoutRestart() = runTest {
        val source = object : PcmSource {
            override fun frames(): Flow<PcmFrame> = listOf(
                PcmFrame(FloatArray(128) { 0.5f }, 48_000),
                PcmFrame(FloatArray(128) { 0.5f }, 48_000)
            ).asFlow()
        }
        val detector = object : PitchDetector {
            override fun detect(samples: FloatArray, sampleRate: Int): Double = 440.0
        }

        var a4 = 440.0
        var frame = 0
        val readings = TunerEngine(source, detector)
            .readings {
                frame++
                if (frame == 2) a4 = 442.0
                TunerConfig(a4Hz = a4, smoothingWindow = 1)
            }
            .toList()

        assertEquals(0.0, readings.first()?.cents ?: 99.0, 0.01)
        val secondCents = readings.last()?.cents ?: 0.0
        assert(secondCents < 0.0)
    }
}
