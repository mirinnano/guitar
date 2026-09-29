package dev.mirinnano.guitartools.audio

import dev.mirinnano.guitartools.music.PitchReading
import kotlinx.coroutines.flow.Flow

interface TunerReader {
    /**
     * Emits null while no usable pitch is present.
     * The provider is evaluated for every frame so settings can change without
     * restarting microphone capture.
     */
    fun readings(configProvider: () -> TunerConfig): Flow<PitchReading?>
}
