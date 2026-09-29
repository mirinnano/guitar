package dev.mirinnano.guitartools.audio

interface MetronomePlayer {
    val isRunning: Boolean

    fun start(
        configProvider: () -> MetronomeConfig,
        onBeat: (BeatEvent) -> Unit = {},
        onError: (Throwable) -> Unit = {}
    )

    fun stop()
}
