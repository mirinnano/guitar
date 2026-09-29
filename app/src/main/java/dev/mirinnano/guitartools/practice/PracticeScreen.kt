package dev.mirinnano.guitartools.practice

import android.content.Intent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.audio.MetronomeConfig
import dev.mirinnano.guitartools.music.Chord
import dev.mirinnano.guitartools.music.ChordQuality
import dev.mirinnano.guitartools.music.CommonChords
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.playback.PlaybackUiState
import dev.mirinnano.guitartools.playback.PlaybackViewModel
import dev.mirinnano.guitartools.song.ExternalChordLinks
import dev.mirinnano.guitartools.song.SongSearchResult
import dev.mirinnano.guitartools.ui.components.ChordDiagram

@Composable
fun PracticeScreen(
    modifier: Modifier = Modifier,
    viewModel: PracticeViewModel = viewModel(),
    playbackViewModel: PlaybackViewModel = viewModel()
) {
    val context = LocalContext.current

    val state by
        viewModel.uiState.collectAsStateWithLifecycle()

    val playbackState by
        playbackViewModel.uiState.collectAsStateWithLifecycle()

    val audioPicker =
        rememberLauncherForActivityResult(
            ActivityResultContracts.OpenDocument()
        ) { uri ->
            if (uri != null) {
                runCatching {
                    context.contentResolver
                        .takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                }

                playbackViewModel.playUri(
                    uri = uri,
                    title = state.title,
                    artist = state.artist
                )
            }
        }

    val progressionState =
        rememberLazyListState()

    LaunchedEffect(
        state.currentStepIndex,
        state.autoScroll
    ) {
        if (
            state.autoScroll &&
            state.progression.isNotEmpty()
        ) {
            progressionState.animateScrollToItem(
                state.currentStepIndex
                    .coerceIn(
                        0,
                        state.progression.lastIndex
                    )
            )
        }
    }

    LaunchedEffect(
        playbackState.positionMs,
        playbackState.hasMedia
    ) {
        if (playbackState.hasMedia) {
            viewModel.syncToPlaybackPosition(
                playbackState.positionMs
            )
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(
                rememberScrollState()
            )
            .padding(
                horizontal = 16.dp,
                vertical = 12.dp
            ),
        verticalArrangement =
            Arrangement.spacedBy(16.dp)
    ) {
        CurrentChordCard(state)

        PracticeTransport(
            state = state,
            onBpm = viewModel::setBpm,
            onToggle = {
                if (state.isPlaying) {
                    viewModel.togglePlayback(
                        syncToBackingTrack =
                            playbackState.hasMedia
                    )
                    if (playbackState.isPlaying) {
                        playbackViewModel.pause()
                    }
                } else {
                    viewModel.togglePlayback(
                        syncToBackingTrack =
                            playbackState.hasMedia
                    )
                    if (playbackState.hasMedia) {
                        playbackViewModel.play()
                    }
                }
            },
            onRestart = {
                viewModel.restart()
                if (playbackState.hasMedia) {
                    playbackViewModel.seekToStart()
                }
            },
            onAutoScroll =
                viewModel::setAutoScroll
        )

        Text(
            text = stringResource(
                R.string.progression
            ),
            style =
                MaterialTheme.typography.titleMedium
        )

        LazyRow(
            state = progressionState,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 92.dp),
            horizontalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            itemsIndexed(
                state.progression
            ) { index, step ->
                ProgressionCard(
                    step = step,
                    active =
                        index ==
                            state.currentStepIndex,
                    onRemove = {
                        viewModel.removeStep(index)
                    },
                    onBeats = {
                        viewModel.setStepBeats(
                            index,
                            it
                        )
                    }
                )
            }
        }

        AddChordCard(
            onAdd = viewModel::addChord
        )

        SongSearchCard(
            state = state,
            onQuery =
                viewModel::setSearchQuery,
            onSearch =
                viewModel::searchSongs,
            onSelect =
                viewModel::selectSong
        )

        state.selectedSong?.let {
            SelectedSongCard(it)
        }

        AudioPlaybackCard(
            state = playbackState,
            onPickAudio = {
                audioPicker.launch(
                    arrayOf("audio/*")
                )
            },
            onToggle =
                playbackViewModel::togglePlayback,
            onStop =
                playbackViewModel::stop,
            onSeek =
                playbackViewModel::seekTo
        )

        ChordProImportCard(
            text = state.importText,
            onText =
                viewModel::setImportText,
            onImport =
                viewModel::importChordPro
        )

        state.searchError?.let {
            Text(
                text = it,
                color =
                    MaterialTheme.colorScheme.error
            )
        }
    }
}

@Composable
private fun CurrentChordCard(
    state: PracticeUiState
) {
    val step =
        state.progression
            .getOrNull(
                state.currentStepIndex
            )

    val shape =
        step?.let { current ->
            CommonChords.all
                .firstOrNull {
                    it.name ==
                        current.lookupName
                }
        }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .primaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalAlignment =
                Alignment.CenterHorizontally,
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = state.title,
                style =
                    MaterialTheme.typography
                        .titleMedium,
                color =
                    MaterialTheme.colorScheme
                        .onPrimaryContainer
            )

            if (state.artist.isNotBlank()) {
                Text(
                    text = state.artist,
                    style =
                        MaterialTheme.typography
                            .bodySmall,
                    color =
                        MaterialTheme.colorScheme
                            .onPrimaryContainer
                )
            }

            Text(
                text = step?.symbol ?: "—",
                style =
                    MaterialTheme.typography
                        .displayMedium,
                color =
                    MaterialTheme.colorScheme
                        .onPrimaryContainer
            )

            if (shape != null) {
                ChordDiagram(
                    shape = shape,
                    modifier = Modifier.width(190.dp),
                    compact = true
                )
            }

            if (step != null) {
                Text(
                    text =
                        (state.beatInStep + 1).toString() +
                            " / " +
                            step.beats,
                    style =
                        MaterialTheme.typography
                            .labelLarge,
                    color =
                        MaterialTheme.colorScheme
                            .onPrimaryContainer
                )
            }
        }
    }
}

@Composable
private fun PracticeTransport(
    state: PracticeUiState,
    onBpm: (Int) -> Unit,
    onToggle: () -> Unit,
    onRestart: () -> Unit,
    onAutoScroll: (Boolean) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(10.dp)
        ) {
            Row(
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Text(
                    text =
                        state.bpm.toString() +
                            " BPM",
                    style =
                        MaterialTheme.typography
                            .titleMedium,
                    modifier =
                        Modifier.weight(1f)
                )

                FilledTonalButton(
                    onClick = onRestart
                ) {
                    Text("↺")
                }

                Button(
                    onClick = onToggle,
                    modifier =
                        Modifier.padding(
                            start = 8.dp
                        )
                ) {
                    Icon(
                        imageVector =
                            if (
                                state.isPlaying
                            ) {
                                Icons.Rounded.Pause
                            } else {
                                Icons.Rounded.PlayArrow
                            },
                        contentDescription = null
                    )
                }
            }

            Slider(
                value =
                    state.bpm.toFloat(),
                onValueChange = {
                    onBpm(it.toInt())
                },
                valueRange =
                    MetronomeConfig
                        .MIN_BPM
                        .toFloat()..
                        MetronomeConfig
                            .MAX_BPM
                            .toFloat()
            )

            Row(
                modifier =
                    Modifier.fillMaxWidth(),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Text(
                    text =
                        stringResource(
                            R.string.auto_scroll
                        ),
                    modifier =
                        Modifier.weight(1f)
                )
                Switch(
                    checked =
                        state.autoScroll,
                    onCheckedChange =
                        onAutoScroll
                )
            }
        }
    }
}

@Composable
private fun ProgressionCard(
    step: ProgressionStep,
    active: Boolean,
    onRemove: () -> Unit,
    onBeats: (Int) -> Unit
) {
    Card(
        modifier = Modifier.width(132.dp),
        colors = CardDefaults.cardColors(
            containerColor =
                if (active) {
                    MaterialTheme.colorScheme
                        .secondaryContainer
                } else {
                    MaterialTheme.colorScheme
                        .surfaceContainerLow
                }
        )
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            horizontalAlignment =
                Alignment.CenterHorizontally,
            verticalArrangement =
                Arrangement.spacedBy(6.dp)
        ) {
            Row(
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Text(
                    text = step.symbol,
                    style =
                        MaterialTheme.typography
                            .titleLarge,
                    modifier =
                        Modifier.weight(1f),
                    maxLines = 1,
                    overflow =
                        TextOverflow.Ellipsis
                )

                IconButton(
                    onClick = onRemove
                ) {
                    Icon(
                        Icons.Rounded.Delete,
                        contentDescription = null
                    )
                }
            }

            Row(
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                FilledTonalButton(
                    onClick = {
                        onBeats(
                            (step.beats - 1)
                                .coerceAtLeast(1)
                        )
                    }
                ) {
                    Text("−")
                }
                Text(
                    text =
                        step.beats.toString(),
                    modifier =
                        Modifier.padding(
                            horizontal = 8.dp
                        )
                )
                FilledTonalButton(
                    onClick = {
                        onBeats(
                            (step.beats + 1)
                                .coerceAtMost(32)
                        )
                    }
                ) {
                    Text("+")
                }
            }
        }
    }
}

@Composable
private fun AddChordCard(
    onAdd: (String) -> Unit
) {
    var root by remember {
        mutableStateOf(Note.C)
    }
    var quality by remember {
        mutableStateOf(
            ChordQuality.MAJOR
        )
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text =
                    stringResource(
                        R.string.add_chord
                    ),
                style =
                    MaterialTheme.typography
                        .titleMedium
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(
                        rememberScrollState()
                    ),
                horizontalArrangement =
                    Arrangement.spacedBy(6.dp)
            ) {
                Note.entries.forEach { note ->
                    FilterChip(
                        selected = root == note,
                        onClick = {
                            root = note
                        },
                        label = {
                            Text(note.displayName)
                        }
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(
                        rememberScrollState()
                    ),
                horizontalArrangement =
                    Arrangement.spacedBy(6.dp)
            ) {
                ChordQuality.entries
                    .forEach { item ->
                        FilterChip(
                            selected =
                                quality == item,
                            onClick = {
                                quality = item
                            },
                            label = {
                                Text(
                                    if (
                                        item.symbol
                                            .isBlank()
                                    ) {
                                        "Major"
                                    } else {
                                        item.symbol
                                    }
                                )
                            }
                        )
                    }
            }

            Button(
                onClick = {
                    onAdd(
                        Chord(
                            root,
                            quality
                        ).name
                    )
                },
                modifier =
                    Modifier.fillMaxWidth()
            ) {
                Icon(
                    Icons.Rounded.Add,
                    contentDescription = null
                )
                Text(
                    text =
                        stringResource(
                            R.string.add
                        ),
                    modifier =
                        Modifier.padding(
                            start = 8.dp
                        )
                )
            }
        }
    }
}

@Composable
private fun SongSearchCard(
    state: PracticeUiState,
    onQuery: (String) -> Unit,
    onSearch: () -> Unit,
    onSelect: (SongSearchResult) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text =
                    stringResource(
                        R.string.search_song
                    ),
                style =
                    MaterialTheme.typography
                        .titleMedium
            )

            OutlinedTextField(
                value = state.searchQuery,
                onValueChange = onQuery,
                modifier =
                    Modifier.fillMaxWidth(),
                singleLine = true,
                leadingIcon = {
                    Icon(
                        Icons.Rounded.Search,
                        contentDescription = null
                    )
                },
                label = {
                    Text(
                        stringResource(
                            R.string.song_or_artist
                        )
                    )
                }
            )

            Button(
                onClick = onSearch,
                enabled =
                    !state.isSearching &&
                        state.searchQuery
                            .isNotBlank(),
                modifier =
                    Modifier.fillMaxWidth()
            ) {
                Text(
                    if (state.isSearching) {
                        stringResource(
                            R.string.searching
                        )
                    } else {
                        stringResource(
                            R.string.search
                        )
                    }
                )
            }

            state.searchResults
                .take(8)
                .forEach { result ->
                    SongResultCard(
                        result = result,
                        onClick = {
                            onSelect(result)
                        }
                    )
                }
        }
    }
}

@Composable
private fun SongResultCard(
    result: SongSearchResult,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .surfaceContainer
        )
    ) {
        Column(
            modifier = Modifier.padding(12.dp)
        ) {
            Text(
                text = result.title,
                style =
                    MaterialTheme.typography
                        .titleSmall
            )
            Text(
                text = result.artist,
                style =
                    MaterialTheme.typography
                        .bodySmall,
                color =
                    MaterialTheme.colorScheme
                        .onSurfaceVariant
            )

            val metadata =
                buildList {
                    result.bpm?.let {
                        add(
                            it.toString() +
                                " BPM"
                        )
                    }
                    result.timeSignature
                        ?.let(::add)
                    result.musicalKey
                        ?.let(::add)
                }.joinToString(" · ")

            if (metadata.isNotBlank()) {
                Text(
                    text = metadata,
                    style =
                        MaterialTheme.typography
                            .labelMedium,
                    color =
                        MaterialTheme.colorScheme
                            .primary
                )
            }
        }
    }
}

@Composable
private fun SelectedSongCard(
    song: SongSearchResult
) {
    val uriHandler = LocalUriHandler.current
    val links =
        remember(
            song.title,
            song.artist
        ) {
            ExternalChordLinks.forSong(
                song.title,
                song.artist
            )
        }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .tertiaryContainer
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = song.title,
                style =
                    MaterialTheme.typography
                        .titleMedium
            )
            Text(song.artist)

            if (song.bpm != null) {
                Text(
                    text =
                        song.bpm.toString() +
                            " BPM",
                    color =
                        MaterialTheme.colorScheme
                            .onTertiaryContainer
                )
            }

            links.forEach { link ->
                FilledTonalButton(
                    onClick = {
                        uriHandler.openUri(
                            link.url
                        )
                    },
                    modifier =
                        Modifier.fillMaxWidth()
                ) {
                    Text(link.label)
                }
            }

            song.sourceUrl?.let {
                FilledTonalButton(
                    onClick = {
                        uriHandler.openUri(it)
                    },
                    modifier =
                        Modifier.fillMaxWidth()
                ) {
                    Text(
                        song.sourceName +
                            "で確認"
                    )
                }
            }
        }
    }
}

@Composable
private fun ChordProImportCard(
    text: String,
    onText: (String) -> Unit,
    onImport: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme
                    .surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text =
                    stringResource(
                        R.string.import_chordpro
                    ),
                style =
                    MaterialTheme.typography
                        .titleMedium
            )

            Text(
                text =
                    stringResource(
                        R.string.import_chordpro_description
                    ),
                style =
                    MaterialTheme.typography
                        .bodySmall,
                color =
                    MaterialTheme.colorScheme
                        .onSurfaceVariant
            )

            OutlinedTextField(
                value = text,
                onValueChange = onText,
                modifier =
                    Modifier.fillMaxWidth(),
                minLines = 4,
                maxLines = 10,
                label = {
                    Text("ChordPro")
                }
            )

            Button(
                onClick = onImport,
                enabled = text.isNotBlank(),
                modifier =
                    Modifier.fillMaxWidth()
            ) {
                Text(
                    stringResource(
                        R.string.import_action
                    )
                )
            }
        }
    }
}


@Composable
private fun AudioPlaybackCard(
    state: PlaybackUiState,
    onPickAudio: () -> Unit,
    onToggle: () -> Unit,
    onStop: () -> Unit,
    onSeek: (Long) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor =
                MaterialTheme.colorScheme.surfaceContainerLow
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = stringResource(
                    R.string.backing_track
                ),
                style =
                    MaterialTheme.typography.titleMedium
            )

            Text(
                text = stringResource(
                    R.string.backing_track_description
                ),
                style =
                    MaterialTheme.typography.bodySmall,
                color =
                    MaterialTheme.colorScheme.onSurfaceVariant
            )

            if (state.title.isNotBlank()) {
                Text(
                    text = state.title,
                    style =
                        MaterialTheme.typography.titleSmall
                )

                if (state.artist.isNotBlank()) {
                    Text(
                        text = state.artist,
                        style =
                            MaterialTheme.typography.bodySmall
                    )
                }
            }

            if (
                state.hasMedia &&
                state.durationMs != null
            ) {
                Text(
                    text =
                        formatPlaybackTime(
                            state.positionMs
                        ) +
                            " / " +
                            formatPlaybackTime(
                                state.durationMs
                            ),
                    style =
                        MaterialTheme.typography.bodySmall,
                    color =
                        MaterialTheme.colorScheme.onSurfaceVariant
                )

                Slider(
                    value =
                        state.positionMs
                            .coerceIn(
                                0L,
                                state.durationMs
                            )
                            .toFloat(),
                    onValueChange = {
                        onSeek(it.toLong())
                    },
                    valueRange =
                        0f..
                            state.durationMs
                                .toFloat(),
                    enabled =
                        state.durationMs > 0L
                )
            }

            Button(
                onClick = onPickAudio,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    stringResource(
                        R.string.choose_audio
                    )
                )
            }

            if (
                state.hasMedia &&
                state.durationMs != null
            ) {
                Text(
                    text =
                        formatPlaybackTime(
                            state.positionMs
                        ) +
                            " / " +
                            formatPlaybackTime(
                                state.durationMs
                            ),
                    style =
                        MaterialTheme.typography
                            .labelMedium,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )

                Slider(
                    value =
                        state.positionMs
                            .coerceAtMost(
                                state.durationMs
                            )
                            .toFloat(),
                    onValueChange = {
                        onSeek(it.toLong())
                    },
                    valueRange =
                        0f..
                            state.durationMs
                                .toFloat()
                                .coerceAtLeast(1f)
                )
            }

            Row(
                modifier =
                    Modifier.fillMaxWidth(),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(
                        R.string.sync_backing_track
                    ),
                    modifier =
                        Modifier.weight(1f)
                )
                Switch(
                    checked = syncEnabled,
                    onCheckedChange =
                        onSyncEnabled
                )
            }

            if (syncEnabled) {
                Text(
                    text = stringResource(
                        R.string.sync_offset_seconds,
                        syncOffsetMs / 1000f
                    ),
                    style =
                        MaterialTheme.typography
                            .labelMedium,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )

                Slider(
                    value =
                        syncOffsetMs.toFloat(),
                    onValueChange = {
                        onSyncOffset(
                            it.toLong()
                        )
                    },
                    valueRange =
                        0f..60_000f
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement =
                    Arrangement.spacedBy(8.dp)
            ) {
                FilledTonalButton(
                    onClick = onToggle,
                    enabled = state.connected,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector =
                            if (state.isPlaying) {
                                Icons.Rounded.Pause
                            } else {
                                Icons.Rounded.PlayArrow
                            },
                        contentDescription = null
                    )

                    Text(
                        text =
                            stringResource(
                                if (state.isPlaying) {
                                    R.string.pause
                                } else {
                                    R.string.play
                                }
                            ),
                        modifier =
                            Modifier.padding(start = 6.dp)
                    )
                }

                FilledTonalButton(
                    onClick = onStop,
                    enabled = state.connected,
                    modifier = Modifier.weight(1f)
                ) {
                    Text(
                        stringResource(
                            R.string.stop
                        )
                    )
                }
            }

            state.errorMessage?.let {
                Text(
                    text = it,
                    color =
                        MaterialTheme.colorScheme.error,
                    style =
                        MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}


private fun formatPlaybackTime(
    millis: Long
): String {
    val totalSeconds =
        (millis.coerceAtLeast(0L) / 1_000L)
            .toInt()
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60

    return minutes.toString() +
        ":" +
        seconds.toString()
            .padStart(2, '0')
}
