package dev.mirinnano.guitartools.ui.tuner

import dev.mirinnano.guitartools.MainDispatcherRule
import dev.mirinnano.guitartools.audio.TunerConfig
import dev.mirinnano.guitartools.audio.TunerReader
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.music.PitchReading
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TunerViewModelTest {
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun exposesReaderOutputAsUiState() = runTest {
        val expected = PitchReading(
            frequencyHz = 440.0,
            midi = 69,
            note = Note.A,
            octave = 4,
            cents = 0.0
        )
        val reader = FakeTunerReader(listOf(expected))
        val viewModel = TunerViewModel(reader)

        viewModel.start()

        assertTrue(viewModel.uiState.value.isListening)
        assertNotNull(viewModel.uiState.value.reading)
        assertEquals(Note.A, viewModel.uiState.value.reading?.note)
    }

    @Test
    fun noSignalClearsPreviousReading() = runTest {
        val expected = PitchReading(440.0, 69, Note.A, 4, 0.0)
        val viewModel = TunerViewModel(
            FakeTunerReader(listOf(expected, null))
        )

        viewModel.start()

        assertNull(viewModel.uiState.value.reading)
    }

    @Test
    fun referencePitchIsClampedWithoutRestartingReader() {
        val reader = FakeTunerReader(emptyList())
        val viewModel = TunerViewModel(reader)

        viewModel.setReferencePitch(500.0)

        assertEquals(480.0, viewModel.uiState.value.a4Hz, 0.001)
        assertEquals(0, reader.subscriptionCount)
    }

    private class FakeTunerReader(
        private val values: List<PitchReading?>
    ) : TunerReader {
        var subscriptionCount = 0

        override fun readings(
            configProvider: () -> TunerConfig
        ): Flow<PitchReading?> {
            subscriptionCount++
            return flowOf(*values.toTypedArray())
        }
    }
}
