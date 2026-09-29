package dev.mirinnano.guitartools.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class MicrophonePcmSource(
    private val sampleRate: Int = 48_000,
    private val frameSize: Int = 4_096
) : PcmSource {

    @SuppressLint("MissingPermission")
    override fun frames(): Flow<PcmFrame> = callbackFlow {
        val recorder = createRecorder()
        recorder.startRecording()

        val job = launch(Dispatchers.IO) {
            val buffer = FloatArray(frameSize)

            while (isActive) {
                val read = recorder.read(
                    buffer,
                    0,
                    buffer.size,
                    AudioRecord.READ_BLOCKING
                )

                when {
                    read > 0 -> {
                        trySend(
                            PcmFrame(
                                samples = buffer.copyOf(read),
                                sampleRate = sampleRate
                            )
                        )
                    }
                    read == AudioRecord.ERROR_DEAD_OBJECT -> {
                        close(IllegalStateException("Microphone disconnected"))
                        break
                    }
                    read < 0 -> {
                        close(IllegalStateException("Microphone read failed: $read"))
                        break
                    }
                }
            }
        }

        awaitClose {
            runCatching { recorder.stop() }
            job.cancel()
            recorder.release()
        }
    }

    @SuppressLint("MissingPermission")
    private fun createRecorder(): AudioRecord {
        val sources = listOf(
            MediaRecorder.AudioSource.UNPROCESSED,
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            MediaRecorder.AudioSource.MIC
        )

        var lastError: Throwable? = null

        for (source in sources) {
            val result = runCatching {
                val minBuffer = AudioRecord.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_FLOAT
                )
                check(minBuffer > 0) { "AudioRecord configuration is unsupported" }

                AudioRecord.Builder()
                    .setAudioSource(source)
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(
                        maxOf(
                            minBuffer,
                            frameSize * Float.SIZE_BYTES * 2
                        )
                    )
                    .build()
            }

            val recorder = result.getOrNull()
            if (recorder != null) {
                if (recorder.state == AudioRecord.STATE_INITIALIZED) {
                    return recorder
                }
                recorder.release()
            }

            lastError = result.exceptionOrNull()
        }

        throw IllegalStateException(
            "No supported microphone configuration",
            lastError
        )
    }
}
