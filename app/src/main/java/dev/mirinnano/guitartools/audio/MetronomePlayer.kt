package dev.mirinnano.guitartools.audio

interface MetronomePlayer {
    val isRunning: Boolean

    fun start(configProvider: () -> MetronomeConfig)

    fun stop()
}
