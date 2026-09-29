package dev.mirinnano.guitartools.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch

class MicrophonePcmSource(
    private val sampleRate: Int = 48_000,
    private val frameSize: Int = 4_096
) : PcmSource {

    @SuppressLint("MissingPermission")
    override fun frames(): Flow<PcmFrame> = callbackFlow {
        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_FLOAT
        )

        check(minBuffer > 0) { "AudioRecord configuration is unsupported" }

        val recorder = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.UNPROCESSED)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minBuffer, frameSize * Float.SIZE_BYTES * 2))
            .build()

        check(recorder.state == AudioRecord.STATE_INITIALIZED) {
            "Failed to initialize microphone"
        }

        recorder.startRecording()

        val job = launch(Dispatchers.IO) {
            val buffer = FloatArray(frameSize)
            while (true) {
                val read = recorder.read(
                    buffer,
                    0,
                    buffer.size,
                    AudioRecord.READ_BLOCKING
                )

                if (read > 0) {
                    trySend(
                        PcmFrame(
                            samples = buffer.copyOf(read),
                            sampleRate = sampleRate
                        )
                    )
                }
            }
        }

        awaitClose {
            job.cancel()
            runCatching { recorder.stop() }
            recorder.release()
        }
    }
}
