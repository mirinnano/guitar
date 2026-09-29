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
        val reader = FakeTunerReader(expected)
        val viewModel = TunerViewModel(reader)

        viewModel.start()

        assertTrue(viewModel.uiState.value.isListening)
        assertNotNull(viewModel.uiState.value.reading)
        assertEquals(Note.A, viewModel.uiState.value.reading?.note)
        assertEquals(440.0, viewModel.uiState.value.reading?.frequencyHz ?: 0.0, 0.001)
    }

    @Test
    fun referencePitchIsClamped() {
        val viewModel = TunerViewModel(FakeTunerReader(null))

        viewModel.setReferencePitch(500.0)

        assertEquals(480.0, viewModel.uiState.value.a4Hz, 0.001)
    }

    private class FakeTunerReader(
        private val reading: PitchReading?
    ) : TunerReader {
        override fun readings(config: TunerConfig): Flow<PitchReading> =
            if (reading == null) flowOf() else flowOf(reading)
    }
}
