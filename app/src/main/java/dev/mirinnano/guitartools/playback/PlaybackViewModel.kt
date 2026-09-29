package dev.mirinnano.guitartools.playback

import android.app.Application
import android.content.ComponentName
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class PlaybackUiState(
    val connected: Boolean = false,
    val isPlaying: Boolean = false,
    val title: String = "",
    val artist: String = "",
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
    }

    private fun playItem(
        item: MediaItem
    ) {
        controller?.apply {
            setMediaItem(item)
            prepare()
            play()
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
                        .orEmpty()
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
        controller?.removeListener(this)
        MediaController.releaseFuture(
            controllerFuture
        )
    }
}
