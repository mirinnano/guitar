package dev.mirinnano.guitartools.playback

import android.app.Application
import android.content.ComponentName
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

data class PlaybackUiState(
    val connected: Boolean = false,
    val isPlaying: Boolean = false,
    val title: String = "",
    val artist: String = "",
    val hasMedia: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long? = null,
    val errorMessage: String? = null
)

class PlaybackViewModel(
    application: Application
) : AndroidViewModel(application),
    Player.Listener {

    private val _uiState =
        MutableStateFlow(PlaybackUiState())

    val uiState: StateFlow<PlaybackUiState> =
        _uiState.asStateFlow()

    private val sessionToken =
        SessionToken(
            application,
            ComponentName(
                application,
                PlaybackService::class.java
            )
        )

    private val controllerFuture =
        MediaController.Builder(
            application,
            sessionToken
        ).buildAsync()

    private var controller:
        MediaController? = null

    private var pendingItem:
        MediaItem? = null

    private var positionJob: Job? = null

    init {
        controllerFuture.addListener(
            {
                runCatching {
                    controllerFuture.get()
                }.onSuccess { mediaController ->
                    controller = mediaController
                    mediaController.addListener(this)

                    _uiState.update {
                        it.copy(
                            connected = true,
                            isPlaying =
                                mediaController.isPlaying,
                            hasMedia =
                                mediaController.mediaItemCount > 0,
                            durationMs =
                                mediaController.duration
                                    .takeIf { value ->
                                        value > 0L
                                    },
                            errorMessage = null
                        )
                    }

                    pendingItem?.let {
                        item ->
                        pendingItem = null
                        playItem(item)
                    }
                }.onFailure { error ->
                    _uiState.update {
                        it.copy(
                            connected = false,
                            errorMessage =
                                error.message
                                    ?: "Playback connection failed"
                        )
                    }
                }
            },
            ContextCompat.getMainExecutor(
                application
            )
        )
    }

    fun playUri(
        uri: Uri,
        title: String,
        artist: String
    ) {
        val metadata =
            MediaMetadata.Builder()
                .setTitle(title)
                .setArtist(artist)
                .build()

        val item =
            MediaItem.Builder()
                .setUri(uri)
                .setMediaMetadata(metadata)
                .build()

        _uiState.update {
            it.copy(
                title = title,
                artist = artist,
                errorMessage = null
            )
        }

        if (controller == null) {
            pendingItem = item
        } else {
            playItem(item)
        }
    }

    fun togglePlayback() {
        val player =
            controller ?: return

        if (player.isPlaying) {
            player.pause()
        } else {
            player.play()
        }
    }

    fun stop() {
        controller?.stop()
        _uiState.update {
            it.copy(
                isPlaying = false,
                positionMs = 0L
            )
        }
        stopPositionUpdates()
    }

    private fun playItem(
        item: MediaItem
    ) {
        controller?.apply {
            setMediaItem(item)
            prepare()
            play()
        }

        _uiState.update {
            it.copy(
                hasMedia = true,
                positionMs = 0L
            )
        }
    }

    override fun onIsPlayingChanged(
        isPlaying: Boolean
    ) {
        _uiState.update {
            it.copy(
                isPlaying = isPlaying
            )
        }

        if (isPlaying) {
            startPositionUpdates()
        } else {
            stopPositionUpdates()
            refreshPosition()
        }
    }

    override fun onMediaItemTransition(
        mediaItem: MediaItem?,
        reason: Int
    ) {
        val metadata =
            mediaItem?.mediaMetadata

        _uiState.update {
            it.copy(
                title =
                    metadata?.title
                        ?.toString()
                        .orEmpty(),
                artist =
                    metadata?.artist
                        ?.toString()
                        .orEmpty(),
                hasMedia =
                    mediaItem != null
            )
        }
    }

    private fun startPositionUpdates() {
        if (positionJob != null) return

        positionJob =
            viewModelScope.launch {
                while (isActive) {
                    refreshPosition()
                    delay(200L)
                }
            }
    }

    private fun stopPositionUpdates() {
        positionJob?.cancel()
        positionJob = null
    }

    private fun refreshPosition() {
        val player = controller ?: return

        _uiState.update {
            it.copy(
                positionMs =
                    player.currentPosition
                        .coerceAtLeast(0L),
                durationMs =
                    player.duration
                        .takeIf { value ->
                            value > 0L
                        }
            )
        }
    }

    override fun onPlayerError(
        error:
            androidx.media3.common.PlaybackException
    ) {
        _uiState.update {
            it.copy(
                isPlaying = false,
                errorMessage =
                    error.message
            )
        }
    }

    override fun onCleared() {
        stopPositionUpdates()
        controller?.removeListener(this)
        MediaController.releaseFuture(
            controllerFuture
        )
    }
}
