package dev.mirinnano.guitartools.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.sin

data class MetronomeConfig(
    val bpm: Int = 120,
    val beatsPerBar: Int = 4,
    val accentFirstBeat: Boolean = true
) {
    init {
        require(bpm in 30..300)
        require(beatsPerBar in 1..12)
    }
}

class MetronomeEngine(
    private val sampleRate: Int = 48_000
) : MetronomePlayer {
    @Volatile
    private var running = false

    private var worker: Thread? = null

    override val isRunning: Boolean
        get() = running

    override fun start(configProvider: () -> MetronomeConfig) {
        if (running) return
        running = true

        worker = thread(name = "MetronomeEngine", isDaemon = true) {
            val minBufferBytes = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            check(minBufferBytes > 0) { "AudioTrack configuration is unsupported" }

            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(minBufferBytes.coerceAtLeast(4_096))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .build()

            check(track.state == AudioTrack.STATE_INITIALIZED) {
                "Failed to initialize AudioTrack"
            }

            var beatInBar = 0
            track.play()

            try {
                while (running) {
                    val config = configProvider()
                    val samplesPerBeat = (sampleRate * 60.0 / config.bpm).toInt()
                    val accented = config.accentFirstBeat && beatInBar == 0

                    val pcm = renderBeat(
                        samplesPerBeat = samplesPerBeat,
                        frequencyHz = if (accented) 1_900.0 else 1_350.0,
                        amplitude = if (accented) 15_000 else 11_000
                    )

                    val written = track.write(
                        pcm,
                        0,
                        pcm.size,
                        AudioTrack.WRITE_BLOCKING
                    )
                    check(written >= 0) { "AudioTrack write failed: $written" }

                    beatInBar = (beatInBar + 1) % config.beatsPerBar
                }
            } finally {
                runCatching { track.pause() }
                runCatching { track.flush() }
                runCatching { track.stop() }
                track.release()
                running = false
            }
        }
    }

    override fun stop() {
        running = false
        worker?.join(300)
        worker = null
    }

    private fun renderBeat(
        samplesPerBeat: Int,
        frequencyHz: Double,
        amplitude: Int
    ): ShortArray {
        val pcm = ShortArray(samplesPerBeat)
        val clickLength = (sampleRate * 0.025).toInt().coerceAtMost(samplesPerBeat)

        for (i in 0 until clickLength) {
            val envelope = 1.0 - i.toDouble() / clickLength
            pcm[i] = (
                sin(2.0 * PI * frequencyHz * i / sampleRate) *
                    envelope *
                    amplitude
                ).toInt().toShort()
        }

        return pcm
    }
}
