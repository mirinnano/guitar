package dev.mirinnano.guitartools.ui.chordwiki

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.OpenInNew
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.SmartDisplay
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedIconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.audio.ScreenOffMetronomePlayer
import dev.mirinnano.guitartools.chordwiki.ChordTimeline
import dev.mirinnano.guitartools.chordwiki.ChordWikiLine
import dev.mirinnano.guitartools.chordwiki.ChordWikiLineType
import dev.mirinnano.guitartools.chordwiki.ChordWikiSearchResult
import dev.mirinnano.guitartools.chordwiki.ChordWikiSong
import dev.mirinnano.guitartools.chordwiki.ChordWikiUiState
import dev.mirinnano.guitartools.chordwiki.ChordWikiViewModel
import dev.mirinnano.guitartools.chordwiki.TimedChordEvent
import dev.mirinnano.guitartools.music.ChordShape
import dev.mirinnano.guitartools.music.CommonChords
import dev.mirinnano.guitartools.music.normalizeChordLookup
import dev.mirinnano.guitartools.ui.components.ChordDiagram
import kotlin.math.roundToInt

@Composable
fun ChordWikiScreen(
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    val factory =
        remember(
            context.applicationContext
        ) {
            object :
                ViewModelProvider.Factory {
                override fun <T : ViewModel> create(
                    modelClass: Class<T>
                ): T {
                    @Suppress("UNCHECKED_CAST")
                    return ChordWikiViewModel(
                        metronome =
                            ScreenOffMetronomePlayer(
                                context.applicationContext
                            )
                    ) as T
                }
            }
        }

    val viewModel: ChordWikiViewModel =
        viewModel(factory = factory)

    val state by
        viewModel.uiState
            .collectAsStateWithLifecycle()

    Box(
        modifier =
            modifier.fillMaxSize()
    ) {
        val song =
            state.selectedSong

        if (song == null) {
            ChordWikiSearchScreen(
                state = state,
                onQueryChange =
                    viewModel::setQuery,
                onSearch =
                    viewModel::search,
                onOpenSong =
                    viewModel::openSong
            )
        } else {
            ChordWikiSongViewer(
                state = state,
                onBack =
                    viewModel::closeSong,
                onBpm =
                    viewModel::setBpm,
                onSeekBeat =
                    viewModel::seekToBeat,
                onToggleInternalPlayback =
                    viewModel::toggleInternalPlayback,
                onAutoScroll =
                    viewModel::setAutoScroll,
                onMetronome =
                    viewModel::setMetronomeEnabled,
                onYoutubeSync =
                    viewModel::setYoutubeSyncEnabled,
                onYoutubeOffset =
                    viewModel::setYoutubeOffsetMs,
                onYoutubeProgress =
                    viewModel::onYoutubeProgress,
                onYoutubeUnavailable =
                    viewModel::onYoutubeUnavailable
            )
        }

        if (state.isLoadingSong) {
            LoadingScrim()
        }
    }
}

@Composable
private fun LoadingScrim() {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color =
            MaterialTheme.colorScheme.surface
                .copy(alpha = 0.9f)
    ) {
        Box(
            contentAlignment =
                Alignment.Center
        ) {
            ElevatedCard {
                Column(
                    modifier =
                        Modifier.padding(24.dp),
                    horizontalAlignment =
                        Alignment.CenterHorizontally,
                    verticalArrangement =
                        Arrangement.spacedBy(14.dp)
                ) {
                    CircularProgressIndicator()

                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_loading_song
                            ),
                        style =
                            MaterialTheme.typography
                                .titleMedium
                    )
                }
            }
        }
    }
}

@Composable
private fun ChordWikiSearchScreen(
    state: ChordWikiUiState,
    onQueryChange: (String) -> Unit,
    onSearch: () -> Unit,
    onOpenSong:
        (ChordWikiSearchResult) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(
                horizontal = 16.dp,
                vertical = 12.dp
            ),
        verticalArrangement =
            Arrangement.spacedBy(14.dp)
    ) {
        ElevatedCard(
            colors =
                CardDefaults
                    .elevatedCardColors(
                        containerColor =
                            MaterialTheme
                                .colorScheme
                                .surfaceContainerLow
                    )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(18.dp),
                horizontalArrangement =
                    Arrangement.spacedBy(14.dp),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Surface(
                    shape =
                        RoundedCornerShape(18.dp),
                    color =
                        MaterialTheme.colorScheme
                            .primaryContainer
                ) {
                    Icon(
                        imageVector =
                            Icons.Rounded.MusicNote,
                        contentDescription = null,
                        modifier =
                            Modifier.padding(14.dp),
                        tint =
                            MaterialTheme.colorScheme
                                .onPrimaryContainer
                    )
                }

                Column(
                    verticalArrangement =
                        Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "ChordWiki Viewer",
                        style =
                            MaterialTheme.typography
                                .titleLarge
                    )

                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_description
                            ),
                        style =
                            MaterialTheme.typography
                                .bodyMedium,
                        color =
                            MaterialTheme.colorScheme
                                .onSurfaceVariant
                    )
                }
            }
        }

        Row(
            modifier =
                Modifier.fillMaxWidth(),
            horizontalArrangement =
                Arrangement.spacedBy(8.dp),
            verticalAlignment =
                Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = state.query,
                onValueChange =
                    onQueryChange,
                modifier =
                    Modifier.weight(1f),
                singleLine = true,
                label = {
                    Text(
                        stringResource(
                            R.string.song_or_artist
                        )
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector =
                            Icons.Rounded.Search,
                        contentDescription = null
                    )
                },
                keyboardOptions =
                    KeyboardOptions(
                        imeAction =
                            ImeAction.Search
                    ),
                keyboardActions =
                    KeyboardActions(
                        onSearch = {
                            onSearch()
                        }
                    )
            )

            FilledIconButton(
                onClick = onSearch,
                enabled =
                    state.query.isNotBlank() &&
                        !state.isSearching
            ) {
                Icon(
                    imageVector =
                        Icons.Rounded.Search,
                    contentDescription =
                        stringResource(
                            R.string.search
                        )
                )
            }
        }

        if (state.isSearching) {
            LinearProgressIndicator(
                modifier =
                    Modifier.fillMaxWidth()
            )
        }

        state.error?.let { message ->
            Surface(
                color =
                    MaterialTheme.colorScheme
                        .errorContainer,
                shape =
                    MaterialTheme.shapes.medium
            ) {
                Text(
                    text = message,
                    modifier =
                        Modifier.padding(12.dp),
                    color =
                        MaterialTheme.colorScheme
                            .onErrorContainer,
                    style =
                        MaterialTheme.typography
                            .bodyMedium
                )
            }
        }

        if (
            state.hasSearched &&
            !state.isSearching &&
            state.results.isEmpty() &&
            state.error == null
        ) {
            Text(
                text =
                    stringResource(
                        R.string.chordwiki_no_results
                    ),
                style =
                    MaterialTheme.typography
                        .bodyMedium,
                color =
                    MaterialTheme.colorScheme
                        .onSurfaceVariant
            )
        }

        LazyColumn(
            modifier =
                Modifier.fillMaxSize(),
            verticalArrangement =
                Arrangement.spacedBy(8.dp),
            contentPadding =
                PaddingValues(
                    bottom = 12.dp
                )
        ) {
            items(
                items = state.results,
                key = { it.url }
            ) { result ->
                Card(
                    onClick = {
                        onOpenSong(result)
                    },
                    modifier =
                        Modifier.fillMaxWidth(),
                    colors =
                        CardDefaults.cardColors(
                            containerColor =
                                MaterialTheme
                                    .colorScheme
                                    .surfaceContainerLow
                        )
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement =
                            Arrangement.spacedBy(12.dp),
                        verticalAlignment =
                            Alignment.CenterVertically
                    ) {
                        Surface(
                            shape =
                                RoundedCornerShape(12.dp),
                            color =
                                MaterialTheme
                                    .colorScheme
                                    .secondaryContainer
                        ) {
                            Icon(
                                imageVector =
                                    Icons.Rounded.MusicNote,
                                contentDescription = null,
                                modifier =
                                    Modifier.padding(10.dp),
                                tint =
                                    MaterialTheme
                                        .colorScheme
                                        .onSecondaryContainer
                            )
                        }

                        Column(
                            modifier =
                                Modifier.weight(1f),
                            verticalArrangement =
                                Arrangement.spacedBy(3.dp)
                        ) {
                            Text(
                                text = result.title,
                                style =
                                    MaterialTheme
                                        .typography
                                        .titleMedium,
                                maxLines = 2,
                                overflow =
                                    TextOverflow.Ellipsis
                            )

                            Text(
                                text = "ChordWiki",
                                style =
                                    MaterialTheme
                                        .typography
                                        .labelMedium,
                                color =
                                    MaterialTheme
                                        .colorScheme
                                        .primary
                            )
                        }

                        Icon(
                            imageVector =
                                Icons.Rounded
                                    .KeyboardArrowDown,
                            contentDescription = null,
                            tint =
                                MaterialTheme
                                    .colorScheme
                                    .onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChordWikiSongViewer(
    state: ChordWikiUiState,
    onBack: () -> Unit,
    onBpm: (Int) -> Unit,
    onSeekBeat: (Float) -> Unit,
    onToggleInternalPlayback: () -> Unit,
    onAutoScroll: (Boolean) -> Unit,
    onMetronome: (Boolean) -> Unit,
    onYoutubeSync: (Boolean) -> Unit,
    onYoutubeOffset: (Long) -> Unit,
    onYoutubeProgress:
        (
            Long,
            Long,
            Boolean
        ) -> Unit,
    onYoutubeUnavailable: () -> Unit
) {
    val song =
        state.selectedSong
            ?: return

    val timeline =
        state.timeline

    val scrollState =
        rememberScrollState()

    val lineOffsets =
        remember(song.sourceUrl) {
            mutableStateMapOf<Int, Float>()
        }

    var viewportTop by
        remember(song.sourceUrl) {
            mutableFloatStateOf(0f)
        }

    val density =
        LocalDensity.current

    val leadPx =
        with(density) {
            176.dp.toPx()
        }

    val activeEvent =
        timeline
            ?.activeEvent(
                state.currentBeat
            )

    LaunchedEffect(
        state.currentBeat,
        state.autoScroll,
        timeline,
        lineOffsets.size
    ) {
        if (
            !state.autoScroll ||
            timeline == null ||
            (
                !state.isPlaying &&
                state.currentBeat <= 0f
            )
        ) {
            return@LaunchedEffect
        }

        val activeLine =
            timeline.activeLine(
                state.currentBeat
            )
                ?: return@LaunchedEffect

        val currentY =
            lineOffsets[
                activeLine.lineIndex
            ]
                ?: return@LaunchedEffect

        val nextLine =
            timeline.lines
                .firstOrNull {
                    it.startBeat >
                        activeLine.startBeat
                }

        val nextY =
            nextLine
                ?.let {
                    lineOffsets[
                        it.lineIndex
                    ]
                }

        val progress =
            timeline.lineProgress(
                activeLine,
                state.currentBeat
            )

        val targetY =
            if (nextY != null) {
                currentY +
                    (nextY - currentY) *
                    progress
            } else {
                currentY
            }

        val targetScroll =
            (
                targetY -
                    leadPx
                ).roundToInt()
                .coerceIn(
                    0,
                    scrollState.maxValue
                )

        if (
            kotlin.math.abs(
                scrollState.value -
                    targetScroll
            ) > 1
        ) {
            scrollState.scrollTo(
                targetScroll
            )
        }
    }

    val youtubeController =
        rememberYouTubePlayerController()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .onGloballyPositioned {
                viewportTop =
                    it.positionInRoot().y
            }
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(
                    start = 16.dp,
                    end = 16.dp,
                    top = 8.dp,
                    bottom = 220.dp
                ),
            verticalArrangement =
                Arrangement.spacedBy(16.dp)
        ) {
            SongHeaderCard(
                song = song,
                state = state,
                timeline = timeline,
                onBack = onBack
            )

            song.youtubeVideoId
                ?.let { videoId ->
                    YouTubePlayerCard(
                        videoId = videoId,
                        state = state,
                        controller =
                            youtubeController,
                        onSync = onYoutubeSync,
                        onProgress =
                            onYoutubeProgress,
                        onUnavailable =
                            onYoutubeUnavailable
                    )
                }

            if (
                song.chordSymbols
                    .isNotEmpty()
            ) {
                UsedChordShapes(
                    symbols =
                        song.chordSymbols
                )
            }

            ChartSectionHeader(
                state = state,
                timeline = timeline
            )

            song.lines
                .forEachIndexed {
                        index,
                        line ->
                    ChordWikiChartLine(
                        line = line,
                        lineIndex = index,
                        activeEvent =
                            activeEvent,
                        isActiveLine =
                            activeEvent
                                ?.lineIndex ==
                                index,
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .onGloballyPositioned {
                                        coordinates ->
                                    lineOffsets[index] =
                                        coordinates
                                            .positionInRoot()
                                            .y -
                                            viewportTop +
                                            scrollState
                                                .value
                                }
                    )
                }

            Spacer(
                modifier =
                    Modifier.height(16.dp)
            )
        }

        TransportDock(
            state = state,
            timeline = timeline,
            youtubeController =
                youtubeController,
            onBpm = onBpm,
            onSeekBeat = onSeekBeat,
            onToggleInternalPlayback =
                onToggleInternalPlayback,
            onAutoScroll = onAutoScroll,
            onMetronome = onMetronome,
            onYoutubeSync =
                onYoutubeSync,
            onYoutubeOffset =
                onYoutubeOffset,
            modifier = Modifier
                .align(
                    Alignment.BottomCenter
                )
                .navigationBarsPadding()
        )
    }
}

@Composable
private fun SongHeaderCard(
    song: ChordWikiSong,
    state: ChordWikiUiState,
    timeline: ChordTimeline?,
    onBack: () -> Unit
) {
    val uriHandler =
        LocalUriHandler.current

    ElevatedCard(
        modifier =
            Modifier.fillMaxWidth(),
        colors =
            CardDefaults
                .elevatedCardColors(
                    containerColor =
                        MaterialTheme
                            .colorScheme
                            .surfaceContainerLow
                )
    ) {
        Column(
            modifier =
                Modifier.padding(18.dp),
            verticalArrangement =
                Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier =
                    Modifier.fillMaxWidth(),
                verticalAlignment =
                    Alignment.Top
            ) {
                IconButton(
                    onClick = onBack
                ) {
                    Icon(
                        imageVector =
                            Icons.Rounded.ArrowBack,
                        contentDescription =
                            stringResource(
                                R.string.back
                            )
                    )
                }

                Column(
                    modifier =
                        Modifier.weight(1f),
                    verticalArrangement =
                        Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = song.title,
                        style =
                            MaterialTheme.typography
                                .headlineSmall,
                        maxLines = 3,
                        overflow =
                            TextOverflow.Ellipsis
                    )

                    if (
                        song.artist.isNotBlank()
                    ) {
                        Text(
                            text = song.artist,
                            style =
                                MaterialTheme
                                    .typography
                                    .titleSmall,
                            color =
                                MaterialTheme
                                    .colorScheme
                                    .onSurfaceVariant
                        )
                    }
                }

                OutlinedIconButton(
                    onClick = {
                        uriHandler.openUri(
                            song.sourceUrl
                        )
                    }
                ) {
                    Icon(
                        imageVector =
                            Icons.Rounded.OpenInNew,
                        contentDescription =
                            stringResource(
                                R.string.chordwiki_source
                            )
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
                    Arrangement.spacedBy(8.dp)
            ) {
                song.key?.let {
                    AssistChip(
                        onClick = {},
                        label = {
                            Text(
                                stringResource(
                                    R.string.chordwiki_key,
                                    it
                                )
                            )
                        }
                    )
                }

                AssistChip(
                    onClick = {},
                    label = {
                        Text(
                            stringResource(
                                R.string.chordwiki_bpm,
                                state.bpm
                            )
                        )
                    }
                )

                AssistChip(
                    onClick = {},
                    label = {
                        Text(
                            state.beatsPerBar
                                .toString() +
                                "/" +
                                state.beatUnit
                                    .toString()
                        )
                    }
                )

                timeline?.let {
                    AssistChip(
                        onClick = {},
                        label = {
                            Text(
                                formatDuration(
                                    it.durationMs(
                                        state.bpm
                                    )
                                )
                            )
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun YouTubePlayerCard(
    videoId: String,
    state: ChordWikiUiState,
    controller:
        YouTubePlayerController,
    onSync: (Boolean) -> Unit,
    onProgress:
        (
            Long,
            Long,
            Boolean
        ) -> Unit,
    onUnavailable: () -> Unit
) {
    ElevatedCard(
        modifier =
            Modifier.fillMaxWidth(),
        colors =
            CardDefaults
                .elevatedCardColors(
                    containerColor =
                        MaterialTheme
                            .colorScheme
                            .surfaceContainerLow
                )
    ) {
        Column(
            verticalArrangement =
                Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(
                        start = 16.dp,
                        end = 12.dp,
                        top = 14.dp
                    ),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Icon(
                    imageVector =
                        Icons.Rounded.SmartDisplay,
                    contentDescription = null,
                    tint =
                        MaterialTheme
                            .colorScheme
                            .primary
                )

                Spacer(
                    Modifier.width(10.dp)
                )

                Column(
                    modifier =
                        Modifier.weight(1f)
                ) {
                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_youtube
                            ),
                        style =
                            MaterialTheme.typography
                                .titleMedium
                    )

                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_youtube_sync_hint
                            ),
                        style =
                            MaterialTheme.typography
                                .bodySmall,
                        color =
                            MaterialTheme.colorScheme
                                .onSurfaceVariant
                    )
                }

                FilterChip(
                    selected =
                        state.youtubeSyncEnabled,
                    onClick = {
                        onSync(
                            !state.youtubeSyncEnabled
                        )
                    },
                    label = {
                        Text(
                            stringResource(
                                R.string.chordwiki_sync
                            )
                        )
                    }
                )
            }

            YouTubeMiniPlayer(
                videoId = videoId,
                controller = controller,
                modifier =
                    Modifier.padding(
                        start = 12.dp,
                        end = 12.dp
                    ),
                onProgress =
                    onProgress,
                onUnavailable =
                    onUnavailable
            )

            if (
                state.youtubeDurationMs >
                0L
            ) {
                Text(
                    text =
                        formatDuration(
                            state.youtubePositionMs
                        ) +
                            " / " +
                            formatDuration(
                                state.youtubeDurationMs
                            ),
                    modifier =
                        Modifier.padding(
                            start = 16.dp,
                            end = 16.dp,
                            bottom = 14.dp
                        ),
                    style =
                        MaterialTheme.typography
                            .labelMedium,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )
            } else {
                Spacer(
                    Modifier.height(4.dp)
                )
            }
        }
    }
}

@Composable
private fun ChartSectionHeader(
    state: ChordWikiUiState,
    timeline: ChordTimeline?
) {
    Column(
        verticalArrangement =
            Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier =
                Modifier.fillMaxWidth(),
            verticalAlignment =
                Alignment.CenterVertically
        ) {
            Text(
                text =
                    stringResource(
                        R.string.chordwiki_chart
                    ),
                modifier =
                    Modifier.weight(1f),
                style =
                    MaterialTheme.typography
                        .titleLarge
            )

            val bar =
                timeline?.barNumber(
                    state.currentBeat
                ) ?: 1

            Text(
                text =
                    stringResource(
                        R.string.chordwiki_bar,
                        bar
                    ),
                style =
                    MaterialTheme.typography
                        .labelLarge,
                color =
                    MaterialTheme.colorScheme
                        .primary
            )
        }

        Text(
            text =
                stringResource(
                    R.string.chordwiki_timing_note
                ),
            style =
                MaterialTheme.typography
                    .bodySmall,
            color =
                MaterialTheme.colorScheme
                    .onSurfaceVariant
        )

        HorizontalDivider()
    }
}

@Composable
private fun TransportDock(
    state: ChordWikiUiState,
    timeline: ChordTimeline?,
    youtubeController:
        YouTubePlayerController,
    onBpm: (Int) -> Unit,
    onSeekBeat: (Float) -> Unit,
    onToggleInternalPlayback: () -> Unit,
    onAutoScroll: (Boolean) -> Unit,
    onMetronome: (Boolean) -> Unit,
    onYoutubeSync: (Boolean) -> Unit,
    onYoutubeOffset: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    if (
        timeline == null ||
        timeline.totalBeats <= 0f
    ) {
        return
    }

    var scrubBeat by
        remember(
            state.selectedSong
                ?.sourceUrl
        ) {
            mutableStateOf<Float?>(
                null
            )
        }

    val displayedBeat =
        scrubBeat
            ?: state.currentBeat

    val chartPositionMs =
        timeline.positionMsForBeat(
            displayedBeat,
            state.bpm
        )

    val chartDurationMs =
        timeline.durationMs(
            state.bpm
        )

    val activeChord =
        timeline
            .activeEvent(displayedBeat)
            ?.symbol
            ?: "—"

    Surface(
        modifier =
            modifier.fillMaxWidth(),
        tonalElevation = 6.dp,
        shadowElevation = 10.dp,
        color =
            MaterialTheme.colorScheme
                .surfaceContainer
    ) {
        Column(
            modifier =
                Modifier.padding(
                    horizontal = 14.dp,
                    vertical = 10.dp
                ),
            verticalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier =
                    Modifier.fillMaxWidth(),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Text(
                    text =
                        formatDuration(
                            chartPositionMs
                        ),
                    style =
                        MaterialTheme.typography
                            .labelMedium,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )

                Spacer(
                    Modifier.weight(1f)
                )

                Text(
                    text = activeChord,
                    style =
                        MaterialTheme.typography
                            .titleMedium,
                    color =
                        MaterialTheme.colorScheme
                            .primary,
                    fontWeight =
                        FontWeight.Bold
                )

                Spacer(
                    Modifier.weight(1f)
                )

                Text(
                    text =
                        formatDuration(
                            chartDurationMs
                        ),
                    style =
                        MaterialTheme.typography
                            .labelMedium,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )
            }

            Slider(
                value =
                    displayedBeat.coerceIn(
                        0f,
                        timeline.totalBeats
                    ),
                onValueChange = {
                    scrubBeat = it
                },
                onValueChangeFinished = {
                    val target =
                        scrubBeat
                            ?: state.currentBeat

                    onSeekBeat(target)

                    if (
                        state.youtubeSyncEnabled
                    ) {
                        val targetMs =
                            state.youtubeOffsetMs +
                                timeline
                                    .positionMsForBeat(
                                        target,
                                        state.bpm
                                    )

                        youtubeController
                            .seekTo(targetMs)
                    }

                    scrubBeat = null
                },
                valueRange =
                    0f..
                        timeline
                            .totalBeats
                            .coerceAtLeast(1f)
            )

            Row(
                modifier =
                    Modifier.fillMaxWidth(),
                horizontalArrangement =
                    Arrangement.spacedBy(10.dp),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                FilledIconButton(
                    onClick = {
                        if (
                            state.youtubeSyncEnabled
                        ) {
                            if (
                                state.youtubePlaying
                            ) {
                                youtubeController
                                    .pause()
                            } else {
                                youtubeController
                                    .play()
                            }
                        } else {
                            onToggleInternalPlayback()
                        }
                    }
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
                        contentDescription =
                            if (
                                state.isPlaying
                            ) {
                                stringResource(
                                    R.string.pause
                                )
                            } else {
                                stringResource(
                                    R.string.play
                                )
                            }
                    )
                }

                Row(
                    modifier = Modifier
                        .weight(1f)
                        .horizontalScroll(
                            rememberScrollState()
                        ),
                    horizontalArrangement =
                        Arrangement.spacedBy(8.dp),
                    verticalAlignment =
                        Alignment.CenterVertically
                ) {
                    FilterChip(
                        selected =
                            state.metronomeEnabled,
                        onClick = {
                            onMetronome(
                                !state.metronomeEnabled
                            )
                        },
                        leadingIcon = {
                            Icon(
                                imageVector =
                                    Icons.Rounded.GraphicEq,
                                contentDescription = null
                            )
                        },
                        label = {
                            Text(
                                stringResource(
                                    R.string.chordwiki_metronome
                                )
                            )
                        }
                    )

                    FilterChip(
                        selected =
                            state.autoScroll,
                        onClick = {
                            onAutoScroll(
                                !state.autoScroll
                            )
                        },
                        label = {
                            Text(
                                stringResource(
                                    R.string.auto_scroll
                                )
                            )
                        }
                    )

                    if (
                        state.selectedSong
                            ?.youtubeVideoId !=
                            null
                    ) {
                        FilterChip(
                            selected =
                                state.youtubeSyncEnabled,
                            onClick = {
                                onYoutubeSync(
                                    !state.youtubeSyncEnabled
                                )
                            },
                            label = {
                                Text(
                                    stringResource(
                                        R.string.chordwiki_sync
                                    )
                                )
                            }
                        )
                    }
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(
                        rememberScrollState()
                    ),
                horizontalArrangement =
                    Arrangement.spacedBy(8.dp),
                verticalAlignment =
                    Alignment.CenterVertically
            ) {
                Text(
                    text = "BPM",
                    style =
                        MaterialTheme.typography
                            .labelLarge
                )

                OutlinedIconButton(
                    onClick = {
                        onBpm(
                            state.bpm - 1
                        )
                    }
                ) {
                    Icon(
                        imageVector =
                            Icons.Rounded.Remove,
                        contentDescription = null
                    )
                }

                Text(
                    text =
                        state.bpm.toString(),
                    style =
                        MaterialTheme.typography
                            .titleMedium,
                    fontWeight =
                        FontWeight.SemiBold
                )

                OutlinedIconButton(
                    onClick = {
                        onBpm(
                            state.bpm + 1
                        )
                    }
                ) {
                    Icon(
                        imageVector =
                            Icons.Rounded.Add,
                        contentDescription = null
                    )
                }

                Text(
                    text =
                        state.beatsPerBar
                            .toString() +
                            "/" +
                            state.beatUnit
                                .toString(),
                    style =
                        MaterialTheme.typography
                            .labelLarge,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )

                if (
                    state.youtubeSyncEnabled
                ) {
                    OutlinedIconButton(
                        onClick = {
                            onYoutubeOffset(
                                state.youtubeOffsetMs -
                                    500L
                            )
                        }
                    ) {
                        Icon(
                            imageVector =
                                Icons.Rounded.Remove,
                            contentDescription = null
                        )
                    }

                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_offset,
                                state.youtubeOffsetMs /
                                    1000f
                            ),
                        style =
                            MaterialTheme.typography
                                .labelMedium
                    )

                    OutlinedIconButton(
                        onClick = {
                            onYoutubeOffset(
                                state.youtubeOffsetMs +
                                    500L
                            )
                        }
                    ) {
                        Icon(
                            imageVector =
                                Icons.Rounded.Add,
                            contentDescription = null
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun UsedChordShapes(
    symbols: List<String>
) {
    Column(
        verticalArrangement =
            Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text =
                stringResource(
                    R.string.chordwiki_used_chords
                ),
            style =
                MaterialTheme.typography
                    .titleMedium
        )

        LazyRow(
            horizontalArrangement =
                Arrangement.spacedBy(8.dp)
        ) {
            items(
                items = symbols,
                key = { it }
            ) { symbol ->
                ChordShapeCard(symbol)
            }
        }
    }
}

@Composable
private fun ChordShapeCard(
    symbol: String
) {
    val shape =
        remember(symbol) {
            findChordShape(symbol)
        }

    Card(
        modifier =
            Modifier.width(140.dp),
        colors =
            CardDefaults.cardColors(
                containerColor =
                    MaterialTheme.colorScheme
                        .surfaceContainerLow
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(10.dp),
            horizontalAlignment =
                Alignment.CenterHorizontally,
            verticalArrangement =
                Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = symbol,
                style =
                    MaterialTheme.typography
                        .titleMedium,
                fontWeight =
                    FontWeight.Bold,
                maxLines = 1,
                overflow =
                    TextOverflow.Ellipsis
            )

            if (shape != null) {
                ChordDiagram(
                    shape = shape,
                    modifier =
                        Modifier
                            .fillMaxWidth(),
                    compact = true
                )
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(132.dp),
                    contentAlignment =
                        Alignment.Center
                ) {
                    Text(
                        text =
                            stringResource(
                                R.string.chordwiki_shape_unavailable
                            ),
                        style =
                            MaterialTheme
                                .typography
                                .bodySmall,
                        color =
                            MaterialTheme
                                .colorScheme
                                .onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun ChordWikiChartLine(
    line: ChordWikiLine,
    lineIndex: Int,
    activeEvent:
        TimedChordEvent?,
    isActiveLine: Boolean,
    modifier: Modifier = Modifier
) {
    when (line.type) {
        ChordWikiLineType.BLANK -> {
            Spacer(
                modifier =
                    modifier.height(10.dp)
            )
        }

        ChordWikiLineType.COMMENT -> {
            Surface(
                modifier = modifier,
                color =
                    MaterialTheme.colorScheme
                        .secondaryContainer
                        .copy(alpha = 0.52f),
                shape =
                    MaterialTheme.shapes.small
            ) {
                Text(
                    text =
                        line.segments
                            .joinToString("") {
                                it.text
                            },
                    modifier =
                        Modifier.padding(
                            horizontal = 12.dp,
                            vertical = 7.dp
                        ),
                    style =
                        MaterialTheme.typography
                            .labelLarge,
                    color =
                        MaterialTheme.colorScheme
                            .onSecondaryContainer
                )
            }
        }

        ChordWikiLineType.CONTENT -> {
            val sectionLike =
                line.chordSymbols.isEmpty() &&
                    line.segments
                        .joinToString("") {
                            it.text
                        }
                        .trim()
                        .let {
                            it.startsWith("[") &&
                                it.endsWith("]")
                        }

            if (sectionLike) {
                Text(
                    text =
                        line.segments
                            .joinToString("") {
                                it.text
                            }
                            .trim(),
                    modifier =
                        modifier.padding(
                            top = 8.dp,
                            bottom = 2.dp
                        ),
                    style =
                        MaterialTheme.typography
                            .titleSmall,
                    color =
                        MaterialTheme.colorScheme
                            .primary,
                    fontWeight =
                        FontWeight.SemiBold
                )
                return
            }

            Surface(
                modifier = modifier,
                color =
                    if (isActiveLine) {
                        MaterialTheme
                            .colorScheme
                            .primaryContainer
                            .copy(alpha = 0.34f)
                    } else {
                        Color.Transparent
                    },
                shape =
                    MaterialTheme.shapes.medium
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(
                            rememberScrollState()
                        )
                        .padding(
                            horizontal =
                                if (isActiveLine) {
                                    10.dp
                                } else {
                                    0.dp
                                },
                            vertical = 6.dp
                        ),
                    verticalAlignment =
                        Alignment.Top
                ) {
                    line.segments
                        .forEachIndexed {
                                segmentIndex,
                                segment ->

                            val activeChord =
                                activeEvent
                                    ?.lineIndex ==
                                    lineIndex &&
                                    activeEvent
                                        .segmentIndex ==
                                    segmentIndex

                            Column(
                                modifier =
                                    Modifier
                                        .widthIn(
                                            min = 22.dp
                                        )
                                        .padding(
                                            end = 2.dp
                                        )
                            ) {
                                if (
                                    segment.chord !=
                                    null
                                ) {
                                    Surface(
                                        color =
                                            if (
                                                activeChord
                                            ) {
                                                MaterialTheme
                                                    .colorScheme
                                                    .primary
                                            } else {
                                                Color.Transparent
                                            },
                                        shape =
                                            RoundedCornerShape(
                                                7.dp
                                            )
                                    ) {
                                        Text(
                                            text =
                                                segment
                                                    .chord,
                                            modifier =
                                                Modifier
                                                    .padding(
                                                        horizontal =
                                                            if (
                                                                activeChord
                                                            ) {
                                                                6.dp
                                                            } else {
                                                                0.dp
                                                            },
                                                        vertical =
                                                            2.dp
                                                    ),
                                            style =
                                                MaterialTheme
                                                    .typography
                                                    .labelLarge,
                                            color =
                                                if (
                                                    activeChord
                                                ) {
                                                    MaterialTheme
                                                        .colorScheme
                                                        .onPrimary
                                                } else {
                                                    MaterialTheme
                                                        .colorScheme
                                                        .primary
                                                },
                                            fontWeight =
                                                FontWeight.Bold,
                                            fontFamily =
                                                FontFamily.Monospace,
                                            maxLines = 1,
                                            softWrap = false
                                        )
                                    }
                                } else {
                                    Text(
                                        text = " ",
                                        style =
                                            MaterialTheme
                                                .typography
                                                .labelLarge
                                    )
                                }

                                Text(
                                    text =
                                        segment.text
                                            .ifEmpty {
                                                " "
                                            },
                                    style =
                                        MaterialTheme
                                            .typography
                                            .bodyLarge,
                                    fontFamily =
                                        FontFamily.Monospace,
                                    maxLines = 1,
                                    softWrap = false
                                )
                            }
                        }
                }
            }
        }
    }
}

private fun findChordShape(
    symbol: String
): ChordShape? {
    val lookup =
        normalizeChordLookup(symbol)
            ?: return null

    return CommonChords.all
        .firstOrNull {
            it.name == lookup
        }
}

private fun formatDuration(
    durationMs: Long
): String {
    val totalSeconds =
        (
            durationMs.coerceAtLeast(0L) /
                1_000L
            )

    val hours =
        totalSeconds / 3_600L

    val minutes =
        (
            totalSeconds % 3_600L
            ) / 60L

    val seconds =
        totalSeconds % 60L

    return if (hours > 0L) {
        "%d:%02d:%02d".format(
            hours,
            minutes,
            seconds
        )
    } else {
        "%d:%02d".format(
            minutes,
            seconds
        )
    }
}
