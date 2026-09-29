package dev.mirinnano.guitartools.ui.metronome

import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.audio.MetronomePlayer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MetronomeViewModelTest {
    @Test
    fun clampsBpmAndControlsInjectedPlayer() {
        val player = FakeMetronomePlayer()
        val viewModel = MetronomeViewModel(player = player)

        viewModel.setBpm(500)
        assertEquals(300, viewModel.uiState.value.bpm)

        viewModel.start()
        assertTrue(viewModel.uiState.value.isPlaying)
        assertTrue(player.isRunning)
        assertEquals(300, player.configProvider?.invoke()?.bpm)

        viewModel.stop()
        assertFalse(viewModel.uiState.value.isPlaying)
        assertFalse(player.isRunning)
    }

    @Test
    fun tapTempoUsesMeasuredInterval() {
        val player = FakeMetronomePlayer()
        var now = 1_000L
        val viewModel = MetronomeViewModel(
            player = player,
            nowMillis = { now }
        )

        viewModel.tapTempo()
        now += 500L
        viewModel.tapTempo()

        assertEquals(120, viewModel.uiState.value.bpm)
    }

    private class FakeMetronomePlayer : MetronomePlayer {
        override var isRunning: Boolean = false
        var configProvider: (() -> MetronomeConfig)? = null

        override fun start(configProvider: () -> MetronomeConfig) {
            this.configProvider = configProvider
            isRunning = true
        }

        override fun stop() {
            isRunning = false
        }
    }
}
