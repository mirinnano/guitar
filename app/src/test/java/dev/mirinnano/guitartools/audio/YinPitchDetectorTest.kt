package dev.mirinnano.guitartools.audio

import kotlin.math.PI
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class YinPitchDetectorTest {
    @Test
    fun detectsA4SineWave() {
        val sampleRate = 48_000
        val samples = FloatArray(8_192) { index ->
            sin(2.0 * PI * 440.0 * index / sampleRate).toFloat()
        }

        val detected = YinPitchDetector().detect(samples, sampleRate)

        assertNotNull(detected)
        assertEquals(440.0, detected!!, 2.0)
    }
}
