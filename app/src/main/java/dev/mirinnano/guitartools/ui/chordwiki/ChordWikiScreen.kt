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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.OpenInNew
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.chordwiki.ChordWikiLine
import dev.mirinnano.guitartools.chordwiki.ChordWikiLineType
import dev.mirinnano.guitartools.chordwiki.ChordWikiSearchResult
import dev.mirinnano.guitartools.chordwiki.ChordWikiSong
import dev.mirinnano.guitartools.chordwiki.ChordWikiUiState
import dev.mirinnano.guitartools.chordwiki.ChordWikiViewModel
import dev.mirinnano.guitartools.music.ChordShape
import dev.mirinnano.guitartools.music.CommonChords
import dev.mirinnano.guitartools.music.normalizeChordLookup
import dev.mirinnano.guitartools.ui.components.ChordDiagram

@Composable
fun ChordWikiScreen(
    modifier: Modifier = Modifier,
    viewModel: ChordWikiViewModel = viewModel()
) {
    val state by
        viewModel.uiState.collectAsStateWithLifecycle()

    Box(
        modifier = modifier.fillMaxSize()
    ) {
        val song = state.selectedSong

        if (song == null) {
            ChordWikiSearchScreen(
                state = state,
                onQueryChange = viewModel::setQuery,
                onSearch = viewModel::search,
                onOpenSong = viewModel::openSong
            )
        } else {
            ChordWikiSongViewer(
                song = song,
                onBack = viewModel::closeSong
            )
        }

        if (state.isLoadingSong) {
            Surface(
                modifier = Modifier.fillMaxSize(),
                color =
                    MaterialTheme.colorScheme.surface
                        .copy(alpha = 0.88f)
            ) {
                Box(
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment =
                            Alignment.CenterHorizontally,
                        verticalArrangement =
                            Arrangement.spacedBy(12.dp)
                    ) {
                        CircularProgressIndicator()
                        Text(
                            stringResource(
                                R.string.chordwiki_loading_song
                            )
                        )
                    }
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
    onOpenSong: (ChordWikiSearchResult) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(
                horizontal = 16.dp,
                vertical = 12.dp
            ),
        verticalArrangement =
            Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text =
                stringResource(
                    R.string.chordwiki_description
                ),
            style = MaterialTheme.typography.bodyMedium,
            color =
                MaterialTheme.colorScheme
                    .onSurfaceVariant
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement =
                Arrangement.spacedBy(8.dp),
            verticalAlignment =
                Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = state.query,
                onValueChange = onQueryChange,
                modifier = Modifier.weight(1f),
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

            Button(
                onClick = onSearch,
                enabled =
                    state.query.isNotBlank() &&
                        !state.isSearching
            ) {
                Text(
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
            Text(
                text = message,
                style =
                    MaterialTheme.typography.bodyMedium,
                color =
                    MaterialTheme.colorScheme.error
            )
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
                    MaterialTheme.typography.bodyMedium,
                color =
                    MaterialTheme.colorScheme
                        .onSurfaceVariant
            )
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement =
                Arrangement.spacedBy(8.dp),
            contentPadding =
                PaddingValues(bottom = 12.dp)
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
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement =
                            Arrangement.spacedBy(4.dp)
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
                }
            }
        }
    }
}

@Composable
private fun ChordWikiSongViewer(
    song: ChordWikiSong,
    onBack: () -> Unit
) {
    val uriHandler = LocalUriHandler.current

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding =
            PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = 8.dp,
                bottom = 28.dp
            ),
        verticalArrangement =
            Arrangement.spacedBy(12.dp)
    ) {
        item(key = "song-header") {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment =
                    Alignment.CenterVertically
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
                        Modifier.weight(1f)
                ) {
                    Text(
                        text = song.title,
                        style =
                            MaterialTheme.typography
                                .headlineSmall,
                        maxLines = 2,
                        overflow =
                            TextOverflow.Ellipsis
                    )

                    if (song.artist.isNotBlank()) {
                        Text(
                            text = song.artist,
                            style =
                                MaterialTheme
                                    .typography
                                    .bodyMedium,
                            color =
                                MaterialTheme
                                    .colorScheme
                                    .onSurfaceVariant
                        )
                    }
                }

                OutlinedButton(
                    onClick = {
                        uriHandler.openUri(
                            song.sourceUrl
                        )
                    }
                ) {
                    Icon(
                        imageVector =
                            Icons.Rounded.OpenInNew,
                        contentDescription = null
                    )
                    Spacer(
                        Modifier.width(6.dp)
                    )
                    Text(
                        stringResource(
                            R.string.chordwiki_source
                        )
                    )
                }
            }
        }

        if (
            song.key != null ||
            song.bpm != null
        ) {
            item(key = "metadata") {
                Row(
                    horizontalArrangement =
                        Arrangement.spacedBy(16.dp)
                ) {
                    song.key?.let {
                        Text(
                            text =
                                stringResource(
                                    R.string.chordwiki_key,
                                    it
                                ),
                            style =
                                MaterialTheme
                                    .typography
                                    .labelLarge
                        )
                    }

                    song.bpm?.let {
                        Text(
                            text =
                                stringResource(
                                    R.string.chordwiki_bpm,
                                    it
                                ),
                            style =
                                MaterialTheme
                                    .typography
                                    .labelLarge
                        )
                    }
                }
            }
        }

        if (song.chordSymbols.isNotEmpty()) {
            item(key = "chord-shapes") {
                UsedChordShapes(
                    symbols = song.chordSymbols
                )
            }
        }

        item(key = "chart-label") {
            Text(
                text =
                    stringResource(
                        R.string.chordwiki_chart
                    ),
                style =
                    MaterialTheme.typography
                        .titleMedium
            )
        }

        items(
            count = song.lines.size,
            key = { index ->
                "line-" + index
            }
        ) { index ->
            ChordWikiChartLine(
                line = song.lines[index]
            )
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
        modifier = Modifier.width(148.dp),
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
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            if (shape != null) {
                ChordDiagram(
                    shape = shape,
                    modifier =
                        Modifier.fillMaxWidth(),
                    compact = true
                )
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(136.dp),
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
    line: ChordWikiLine
) {
    when (line.type) {
        ChordWikiLineType.BLANK -> {
            Spacer(
                modifier = Modifier.height(8.dp)
            )
        }

        ChordWikiLineType.COMMENT -> {
            Surface(
                color =
                    MaterialTheme.colorScheme
                        .surfaceContainerLow,
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
                            horizontal = 10.dp,
                            vertical = 6.dp
                        ),
                    style =
                        MaterialTheme.typography
                            .labelLarge,
                    color =
                        MaterialTheme.colorScheme
                            .onSurfaceVariant
                )
            }
        }

        ChordWikiLineType.CONTENT -> {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(
                        rememberScrollState()
                    ),
                verticalAlignment =
                    Alignment.Top
            ) {
                line.segments.forEach { segment ->
                    Column(
                        modifier = Modifier
                            .widthIn(min = 20.dp)
                            .padding(end = 1.dp)
                    ) {
                        Text(
                            text =
                                segment.chord
                                    ?: " ",
                            style =
                                MaterialTheme
                                    .typography
                                    .labelLarge,
                            color =
                                if (
                                    segment.chord != null
                                ) {
                                    MaterialTheme
                                        .colorScheme
                                        .primary
                                } else {
                                    MaterialTheme
                                        .colorScheme
                                        .onSurface
                                },
                            fontWeight =
                                if (
                                    segment.chord != null
                                ) {
                                    FontWeight.Bold
                                } else {
                                    FontWeight.Normal
                                },
                            fontFamily =
                                FontFamily.Monospace,
                            maxLines = 1,
                            softWrap = false
                        )

                        Text(
                            text =
                                segment.text
                                    .ifEmpty { " " },
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
