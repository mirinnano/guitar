package dev.mirinnano.guitartools.audio

import dev.mirinnano.guitartools.music.PitchReading
import kotlinx.coroutines.flow.Flow

interface TunerReader {
    fun readings(config: TunerConfig = TunerConfig()): Flow<PitchReading>
}
