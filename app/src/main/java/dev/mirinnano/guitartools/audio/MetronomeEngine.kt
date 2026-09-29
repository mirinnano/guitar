package dev.mirinnano.guitartools.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.sin

class MetronomeEngine(
    private val sampleRate: Int = 48_000
) {
    @Volatile
    private var running = false

    private var worker: Thread? = null

    fun start(bpmProvider: () -> Int) {
        if (running) return
        running = true

        worker = thread(name = "MetronomeEngine") {
            val minBuffer = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
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
                .setBufferSizeInBytes(minBuffer.coerceAtLeast(sampleRate / 2))
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            track.play()

            try {
                while (running) {
                    val bpm = bpmProvider().coerceIn(30, 300)
                    val samplesPerBeat = (sampleRate * 60.0 / bpm).toInt()
                    val pcm = ShortArray(samplesPerBeat)
                    val clickLength = (sampleRate * 0.025).toInt().coerceAtMost(samplesPerBeat)

                    for (i in 0 until clickLength) {
                        val envelope = 1.0 - i.toDouble() / clickLength
                        pcm[i] = (sin(2.0 * PI * 1400.0 * i / sampleRate) * envelope * 12_000).toInt().toShort()
                    }

                    track.write(pcm, 0, pcm.size, AudioTrack.WRITE_BLOCKING)
                }
            } finally {
                track.stop()
                track.release()
            }
        }
    }

    fun stop() {
        running = false
        worker?.join(250)
        worker = null
    }
}
