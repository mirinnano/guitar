package dev.mirinnano.guitartools.audio

/**
 * Small boundary between UI state and Android audio playback.
 *
 * Keeping this interface tiny makes the ViewModel easy to test without
 * creating a real AudioTrack.
 */
interface MetronomePlayer {
    val isRunning: Boolean

    fun start(
        configProvider: () -> MetronomeConfig,
        onError: (Throwable) -> Unit = {}
    )

    fun stop()
}
