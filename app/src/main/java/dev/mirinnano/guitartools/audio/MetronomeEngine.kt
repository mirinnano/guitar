package dev.mirinnano.guitartools.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.sin

data class MetronomeConfig(
    val bpm: Int = DEFAULT_BPM,
    val beatsPerBar: Int = DEFAULT_BEATS_PER_BAR,
    val accentFirstBeat: Boolean = true
) {
    init {
        require(bpm in MIN_BPM..MAX_BPM)
        require(beatsPerBar in MIN_BEATS_PER_BAR..MAX_BEATS_PER_BAR)
    }

    companion object {
        const val MIN_BPM = 30
        const val MAX_BPM = 300
        const val DEFAULT_BPM = 120

        const val MIN_BEATS_PER_BAR = 1
        const val MAX_BEATS_PER_BAR = 12
        const val DEFAULT_BEATS_PER_BAR = 4
    }
}

/**
 * Sample-clock driven metronome.
 *
 * Each beat is rendered as PCM containing a short click followed by silence.
 * Writing the entire beat to AudioTrack keeps timing on the audio clock instead
 * of depending on Thread.sleep()/delay() accuracy.
 */
class MetronomeEngine(
    private val sampleRate: Int = DEFAULT_SAMPLE_RATE
) : MetronomePlayer {

    private val lock = Any()

    @Volatile
    private var activeSession: PlaybackSession? = null

    override val isRunning: Boolean
        get() = activeSession?.keepRunning?.get() == true

    override fun start(
        configProvider: () -> MetronomeConfig,
        onError: (Throwable) -> Unit
    ) {
        synchronized(lock) {
            if (activeSession != null) return

            val session = PlaybackSession()
            activeSession = session

            session.worker = thread(
                name = "GuitarTools-Metronome",
                isDaemon = true
            ) {
                runCatching {
                    playLoop(
                        session = session,
                        configProvider = configProvider
                    )
                }.onFailure(onError)

                synchronized(lock) {
                    if (activeSession === session) {
                        activeSession = null
                    }
                }
            }
        }
    }

    override fun stop() {
        val session = synchronized(lock) {
            activeSession?.also { it.keepRunning.set(false) }
        } ?: return

        session.worker?.join(STOP_JOIN_TIMEOUT_MS)

        synchronized(lock) {
            if (activeSession === session && session.worker?.isAlive != true) {
                activeSession = null
            }
        }
    }

    private fun playLoop(
        session: PlaybackSession,
        configProvider: () -> MetronomeConfig
    ) {
        val track = createAudioTrack()

        try {
            track.play()

            var beatInBar = 0

            while (session.keepRunning.get()) {
                val config = configProvider()
                val samplesPerBeat = samplesPerBeat(config.bpm)
                val isAccent = config.accentFirstBeat && beatInBar == 0

                val beat = renderBeat(
                    samplesPerBeat = samplesPerBeat,
                    frequencyHz = if (isAccent) ACCENT_FREQUENCY_HZ else CLICK_FREQUENCY_HZ,
                    amplitude = if (isAccent) ACCENT_AMPLITUDE else CLICK_AMPLITUDE
                )

                writeFully(
                    track = track,
                    samples = beat,
                    shouldContinue = { session.keepRunning.get() }
                )

                beatInBar = (beatInBar + 1) % config.beatsPerBar
            }
        } finally {
            runCatching { track.pause() }
            runCatching { track.flush() }
            runCatching { track.stop() }
            track.release()
            session.keepRunning.set(false)
        }
    }

    private fun createAudioTrack(): AudioTrack {
        val minBufferBytes = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        check(minBufferBytes > 0) {
            "Unsupported AudioTrack configuration: $minBufferBytes"
        }

        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    // A metronome is foreground audio. MEDIA uses the normal
                    // media-volume slider instead of notification/system volume.
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(minBufferBytes.coerceAtLeast(MIN_BUFFER_BYTES))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
            .also { track ->
                check(track.state == AudioTrack.STATE_INITIALIZED) {
                    "AudioTrack failed to initialize"
                }
            }
    }

    private fun writeFully(
        track: AudioTrack,
        samples: ShortArray,
        shouldContinue: () -> Boolean
    ) {
        var offset = 0

        while (offset < samples.size && shouldContinue()) {
            val written = track.write(
                samples,
                offset,
                samples.size - offset,
                AudioTrack.WRITE_BLOCKING
            )

            when {
                written > 0 -> offset += written
                written == 0 -> Unit
                else -> error("AudioTrack write failed: $written")
            }
        }
    }

    private fun samplesPerBeat(bpm: Int): Int =
        (sampleRate * SECONDS_PER_MINUTE / bpm).toInt()

    private fun renderBeat(
        samplesPerBeat: Int,
        frequencyHz: Double,
        amplitude: Int
    ): ShortArray {
        val samples = ShortArray(samplesPerBeat)
        val clickLength = (sampleRate * CLICK_LENGTH_SECONDS)
            .toInt()
            .coerceAtMost(samplesPerBeat)

        for (index in 0 until clickLength) {
            val fade = 1.0 - index.toDouble() / clickLength
            val wave = sin(2.0 * PI * frequencyHz * index / sampleRate)

            samples[index] = (wave * fade * amplitude)
                .toInt()
                .toShort()
        }

        return samples
    }

    private class PlaybackSession {
        val keepRunning = AtomicBoolean(true)

        @Volatile
        var worker: Thread? = null
    }

    private companion object {
        const val DEFAULT_SAMPLE_RATE = 48_000
        const val MIN_BUFFER_BYTES = 8_192
        const val STOP_JOIN_TIMEOUT_MS = 1_000L

        const val SECONDS_PER_MINUTE = 60.0
        const val CLICK_LENGTH_SECONDS = 0.035

        const val CLICK_FREQUENCY_HZ = 1_200.0
        const val ACCENT_FREQUENCY_HZ = 1_800.0

        const val CLICK_AMPLITUDE = 19_000
        const val ACCENT_AMPLITUDE = 25_000
    }
}
