package dev.mirinnano.guitartools.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.floor
import kotlin.math.sin

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
        onBeat: (BeatEvent) -> Unit,
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
                        configProvider = configProvider,
                        onBeat = onBeat
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
        configProvider: () -> MetronomeConfig,
        onBeat: (BeatEvent) -> Unit
    ) {
        val track = createAudioTrack()
        val initial = configProvider()

        var beatInBar = 0
        var subdivisionIndex = 0
        var remainingCountInPulses =
            initial.countInBars *
                initial.beatsPerBar *
                initial.subdivision.pulsesPerBeat

        try {
            track.play()

            while (session.keepRunning.get()) {
                val config = configProvider()
                val pulsesPerBeat = config.subdivision.pulsesPerBeat

                if (beatInBar >= config.beatsPerBar) {
                    beatInBar = 0
                }
                if (subdivisionIndex >= pulsesPerBeat) {
                    subdivisionIndex = 0
                }

                val isMainBeat = subdivisionIndex == 0
                val isCountIn = remainingCountInPulses > 0
                val beatAccent = config.accentForBeat(beatInBar)

                val effectiveAccent = when {
                    isCountIn && beatInBar == 0 && isMainBeat ->
                        BeatAccent.ACCENT
                    isCountIn -> BeatAccent.NORMAL
                    isMainBeat -> beatAccent
                    else -> BeatAccent.NORMAL
                }

                onBeat(
                    BeatEvent(
                        beatInBar = beatInBar,
                        subdivisionIndex = subdivisionIndex,
                        isCountIn = isCountIn,
                        accent = effectiveAccent
                    )
                )

                val samplesPerPulse = samplesPerPulse(
                    bpm = config.bpm,
                    pulsesPerBeat = pulsesPerBeat
                )

                val shouldClick =
                    effectiveAccent != BeatAccent.MUTE

                val pulse = if (shouldClick) {
                    renderClick(
                        samplesPerPulse = samplesPerPulse,
                        sound = config.clickSound,
                        accent = effectiveAccent,
                        isSubdivision = !isMainBeat
                    )
                } else {
                    ShortArray(samplesPerPulse)
                }

                writeFully(
                    track = track,
                    samples = pulse,
                    shouldContinue = {
                        session.keepRunning.get()
                    }
                )

                if (remainingCountInPulses > 0) {
                    remainingCountInPulses--
                }

                subdivisionIndex++
                if (subdivisionIndex >= pulsesPerBeat) {
                    subdivisionIndex = 0
                    beatInBar =
                        (beatInBar + 1) %
                            config.beatsPerBar
                }
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
            .setBufferSizeInBytes(
                minBufferBytes.coerceAtLeast(
                    MIN_BUFFER_BYTES
                )
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
            .also { track ->
                check(
                    track.state ==
                        AudioTrack.STATE_INITIALIZED
                ) {
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

        while (
            offset < samples.size &&
            shouldContinue()
        ) {
            val chunkSize = minOf(
                samples.size - offset,
                WRITE_CHUNK_SAMPLES
            )

            val written = track.write(
                samples,
                offset,
                chunkSize,
                AudioTrack.WRITE_BLOCKING
            )

            when {
                written > 0 -> offset += written
                written == 0 -> Unit
                else -> error(
                    "AudioTrack write failed: $written"
                )
            }
        }
    }

    private fun samplesPerPulse(
        bpm: Int,
        pulsesPerBeat: Int
    ): Int =
        (
            sampleRate *
                SECONDS_PER_MINUTE /
                bpm /
                pulsesPerBeat
            ).toInt().coerceAtLeast(1)

    private fun renderClick(
        samplesPerPulse: Int,
        sound: ClickSound,
        accent: BeatAccent,
        isSubdivision: Boolean
    ): ShortArray {
        val samples = ShortArray(samplesPerPulse)
        val clickLength = (
            sampleRate *
                if (sound == ClickSound.HI_HAT) {
                    HI_HAT_LENGTH_SECONDS
                } else {
                    CLICK_LENGTH_SECONDS
                }
            ).toInt().coerceAtMost(samplesPerPulse)

        val baseAmplitude = when {
            isSubdivision -> 10_000
            accent == BeatAccent.ACCENT -> 25_000
            else -> 18_000
        }

        for (index in 0 until clickLength) {
            val fade =
                1.0 - index.toDouble() /
                    clickLength.coerceAtLeast(1)

            val value = when (sound) {
                ClickSound.DIGITAL -> {
                    val hz = if (
                        accent == BeatAccent.ACCENT &&
                        !isSubdivision
                    ) {
                        1_800.0
                    } else {
                        1_200.0
                    }
                    sin(
                        2.0 * PI * hz *
                            index / sampleRate
                    )
                }

                ClickSound.WOOD -> {
                    val low = sin(
                        2.0 * PI * 760.0 *
                            index / sampleRate
                    )
                    val high = sin(
                        2.0 * PI * 1_320.0 *
                            index / sampleRate
                    )
                    low * 0.72 + high * 0.28
                }

                ClickSound.HI_HAT -> {
                    val noisy =
                        sin(index * 12.9898) *
                            43_758.5453
                    val fraction =
                        noisy - floor(noisy)
                    fraction * 2.0 - 1.0
                }
            }

            samples[index] = (
                value *
                    fade *
                    baseAmplitude
                ).toInt()
                .coerceIn(
                    Short.MIN_VALUE.toInt(),
                    Short.MAX_VALUE.toInt()
                )
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
        const val WRITE_CHUNK_SAMPLES = 2_048
        const val STOP_JOIN_TIMEOUT_MS = 1_000L

        const val SECONDS_PER_MINUTE = 60.0
        const val CLICK_LENGTH_SECONDS = 0.035
        const val HI_HAT_LENGTH_SECONDS = 0.055
    }
}
