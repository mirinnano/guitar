package dev.mirinnano.guitartools.audio

import kotlinx.coroutines.flow.Flow

data class PcmFrame(
    val samples: FloatArray,
    val sampleRate: Int
)

interface PcmSource {
    fun frames(): Flow<PcmFrame>
}
