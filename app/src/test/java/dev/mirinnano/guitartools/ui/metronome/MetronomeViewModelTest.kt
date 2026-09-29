package dev.mirinnano.guitartools.ui.metronome

import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomePlayer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MetronomeViewModelTest {

    @Test
    fun bpmIsClampedAndPlaybackIsControlled() {
        val player = FakeMetronomePlayer()
        val viewModel = MetronomeViewModel(player = player)

        viewModel.setBpm(500)

        assertEquals(
            MetronomeConfig.MAX_BPM,
            viewModel.uiState.value.bpm
        )

        viewModel.togglePlayback()

        assertTrue(viewModel.uiState.value.isPlaying)
        assertTrue(player.isRunning)
        assertEquals(
            MetronomeConfig.MAX_BPM,
            player.configProvider?.invoke()?.bpm
        )

        viewModel.togglePlayback()

        assertFalse(viewModel.uiState.value.isPlaying)
        assertFalse(player.isRunning)
    }

    @Test
    fun tapTempoUsesMeasuredInterval() {
        var now = 1_000L
        val viewModel = MetronomeViewModel(
            player = FakeMetronomePlayer(),
            nowMillis = { now }
        )

        viewModel.registerTempoTap()
        now += 500L
        viewModel.registerTempoTap()

        assertEquals(120, viewModel.uiState.value.bpm)
    }

    @Test
    fun playbackFailureIsExposedToUi() {
        val player = FakeMetronomePlayer()
        val viewModel = MetronomeViewModel(player = player)

        viewModel.togglePlayback()
        player.fail(IllegalStateException("test"))

        assertFalse(viewModel.uiState.value.isPlaying)
        assertTrue(viewModel.uiState.value.playbackFailed)
    }

    private class FakeMetronomePlayer : MetronomePlayer {
        override var isRunning: Boolean = false

        var configProvider: (() -> MetronomeConfig)? = null
        private var onError: ((Throwable) -> Unit)? = null

        override fun start(
            configProvider: () -> MetronomeConfig,
            onError: (Throwable) -> Unit
        ) {
            this.configProvider = configProvider
            this.onError = onError
            isRunning = true
        }

        override fun stop() {
            isRunning = false
        }

        fun fail(error: Throwable) {
            isRunning = false
            onError?.invoke(error)
        }
    }
}
