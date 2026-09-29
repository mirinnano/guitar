package dev.mirinnano.guitartools.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.sin

interface TonePlayer {
    fun play(frequencyHz: Double)
    fun stop()
}

class ReferenceTonePlayer(
    private val sampleRate: Int = 48_000
) : TonePlayer {

    private val lock = Any()

    @Volatile
    private var session: ToneSession? = null

    override fun play(
        frequencyHz: Double
    ) {
        require(frequencyHz > 0.0)

        stop()

        synchronized(lock) {
            val next = ToneSession()
            session = next

            next.worker = thread(
                name =
                    "GuitarTools-ReferenceTone",
                isDaemon = true
            ) {
                runCatching {
                    playTone(
                        frequencyHz,
                        next
                    )
                }

                synchronized(lock) {
                    if (session === next) {
                        session = null
                    }
                }
            }
        }
    }

    override fun stop() {
        val current = synchronized(lock) {
            session?.also {
                it.running.set(false)
            }
        } ?: return

        current.worker?.join(250L)

        synchronized(lock) {
            if (
                session === current &&
                current.worker?.isAlive != true
            ) {
                session = null
            }
        }
    }

    private fun playTone(
        frequencyHz: Double,
        toneSession: ToneSession
    ) {
        val sampleCount =
            (
                sampleRate *
                    TONE_DURATION_SECONDS
                ).toInt()

        val samples =
            ShortArray(sampleCount)

        samples.indices.forEach { index ->
            val fadeIn = (
                index.toDouble() /
                    (sampleRate * 0.02)
                ).coerceIn(0.0, 1.0)

            val fadeOut = (
                (sampleCount - index)
                    .toDouble() /
                    (sampleRate * 0.05)
                ).coerceIn(0.0, 1.0)

            val wave = sin(
                2.0 * PI *
                    frequencyHz *
                    index / sampleRate
            )

            samples[index] = (
                wave *
                    fadeIn *
                    fadeOut *
                    10_000
                ).toInt()
                .toShort()
        }

        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(
                        AudioAttributes
                            .USAGE_MEDIA
                    )
                    .setContentType(
                        AudioAttributes
                            .CONTENT_TYPE_MUSIC
                    )
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(
                        AudioFormat
                            .ENCODING_PCM_16BIT
                    )
                    .setChannelMask(
                        AudioFormat
                            .CHANNEL_OUT_MONO
                    )
                    .build()
            )
            .setBufferSizeInBytes(
                samples.size * 2
            )
            .setTransferMode(
                AudioTrack.MODE_STATIC
            )
            .build()

        try {
            check(
                track.state ==
                    AudioTrack.STATE_INITIALIZED
            )

            track.write(
                samples,
                0,
                samples.size
            )

            if (
                toneSession.running.get()
            ) {
                track.play()

                while (
                    toneSession.running.get() &&
                    track.playbackHeadPosition <
                    samples.size
                ) {
                    Thread.sleep(20L)
                }
            }
        } finally {
            runCatching { track.stop() }
            track.release()
            toneSession.running.set(false)
        }
    }

    private class ToneSession {
        val running = AtomicBoolean(true)

        @Volatile
        var worker: Thread? = null
    }

    private companion object {
        const val TONE_DURATION_SECONDS =
            1.2
    }
}
