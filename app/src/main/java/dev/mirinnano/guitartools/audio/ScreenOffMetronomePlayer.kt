package dev.mirinnano.guitartools.audio

import android.content.Context
import android.os.PowerManager

/**
 * Keeps the sample-clock metronome running while the display is off.
 *
 * The wake lock is held only while the metronome is actively playing and has
 * a hard timeout as a final safety net.
 */
class ScreenOffMetronomePlayer(
    context: Context,
    private val delegate:
        MetronomePlayer =
        MetronomeEngine()
) : MetronomePlayer {

    private val wakeLock =
        (
            context.applicationContext
                .getSystemService(
                    Context.POWER_SERVICE
                ) as PowerManager
            ).newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "GuitarTools:Metronome"
            ).apply {
                setReferenceCounted(false)
            }

    override val isRunning: Boolean
        get() = delegate.isRunning

    override fun start(
        configProvider: () -> MetronomeConfig,
        onBeat: (BeatEvent) -> Unit,
        onError: (Throwable) -> Unit
    ) {
        if (!wakeLock.isHeld) {
            wakeLock.acquire(
                MAX_WAKE_LOCK_MS
            )
        }

        delegate.start(
            configProvider = configProvider,
            onBeat = onBeat,
            onError = { error ->
                releaseWakeLock()
                onError(error)
            }
        )
    }

    override fun stop() {
        delegate.stop()
        releaseWakeLock()
    }

    private fun releaseWakeLock() {
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
    }

    private companion object {
        const val MAX_WAKE_LOCK_MS =
            8 * 60 * 60 * 1_000L
    }
}
