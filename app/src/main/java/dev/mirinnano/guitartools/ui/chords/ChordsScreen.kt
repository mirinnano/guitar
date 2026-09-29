package dev.mirinnano.guitartools.ui.chords

import androidx.annotation.StringRes
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.music.ChordQuality
import dev.mirinnano.guitartools.music.ChordShape
import dev.mirinnano.guitartools.music.CommonChords
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.ui.components.ChordDiagram

private const val CHORDS_PER_ROW = 4

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChordsScreen(
    modifier: Modifier = Modifier
) {
    var query by remember { mutableStateOf("") }
    var selectedQuality by remember {
        mutableStateOf<ChordQuality?>(null)
    }
    var selectedChord by remember {
        mutableStateOf<ChordShape?>(null)
    }

    val groupedChords = remember(query, selectedQuality) {
        Note.entries.mapNotNull { root ->
            val visible = CommonChords
                .forRoot(root)
                .filter { shape ->
                    matchesFilter(
                        shape = shape,
                        query = query,
                        quality = selectedQuality
                    )
                }

            if (visible.isEmpty()) {
                null
            } else {
                root to visible
            }
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        ChordSearch(
            query = query,
            onQueryChange = { query = it }
        )

        ChordQualityFilter(
            selected = selectedQuality,
            onSelect = { selectedQuality = it }
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            groupedChords.forEach { (root, chords) ->
                item(
                    key = "header-${root.name}"
                ) {
                    RootSectionHeader(
                        root = root,
                        chordCount = chords.size
                    )
                }

                chords
                    .chunked(CHORDS_PER_ROW)
                    .forEachIndexed { rowIndex, row ->
                        item(
                            key = "${root.name}-$rowIndex"
                        ) {
                            ChordGridRow(
                                chords = row,
                                onChordClick = {
                                    selectedChord = it
                                }
                            )
                        }
                    }
            }
        }
    }

    selectedChord?.let { shape ->
        ModalBottomSheet(
            onDismissRequest = {
                selectedChord = null
            }
        ) {
            ChordDetailSheet(shape)
        }
    }
}

private fun matchesFilter(
    shape: ChordShape,
    query: String,
    quality: ChordQuality?
): Boolean {
    val matchesQuery =
        query.isBlank() ||
            shape.name.contains(query, ignoreCase = true)

    val matchesQuality =
        quality == null ||
            shape.chord.quality == quality

    return matchesQuery && matchesQuality
}

@Composable
private fun ChordSearch(
    query: String,
    onQueryChange: (String) -> Unit
) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = {
            Text(
                stringResource(R.string.search_chords)
            )
        },
        leadingIcon = {
            Icon(
                imageVector = Icons.Rounded.Search,
                contentDescription = null
            )
        }
    )
}

@Composable
private fun ChordQualityFilter(
    selected: ChordQuality?,
    onSelect: (ChordQuality?) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        FilterChip(
            selected = selected == null,
            onClick = { onSelect(null) },
            label = {
                Text(stringResource(R.string.all))
            }
        )

        ChordQuality.entries.forEach { quality ->
            FilterChip(
                selected = selected == quality,
                onClick = { onSelect(quality) },
                label = {
                    Text(
                        stringResource(
                            quality.labelResource()
                        )
                    )
                }
            )
        }
    }
}

@Composable
private fun RootSectionHeader(
    root: Note,
    chordCount: Int
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        verticalAlignment = Alignment.Bottom
    ) {
        Text(
            text = root.displayName,
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.weight(1f)
        )

        Text(
            text = stringResource(
                R.string.chord_section_count,
                chordCount
            ),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun ChordGridRow(
    chords: List<ChordShape>,
    onChordClick: (ChordShape) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        chords.forEach { shape ->
            Card(
                onClick = {
                    onChordClick(shape)
                },
                modifier = Modifier
                    .weight(1f)
                    .height(64.dp),
                colors = CardDefaults.cardColors(
                    containerColor =
                        MaterialTheme.colorScheme.surfaceContainerLow
                )
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = shape.name,
                        style = MaterialTheme.typography.labelLarge,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }

        repeat(CHORDS_PER_ROW - chords.size) {
            Spacer(
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun ChordDetailSheet(
    shape: ChordShape
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = 24.dp,
                end = 24.dp,
                bottom = 32.dp
            ),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(
            text = shape.name,
            style = MaterialTheme.typography.headlineLarge
        )

        Text(
            text = stringResource(R.string.chord_tones),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Text(
            text = shape.chord.notes.joinToString(" · ") {
                it.displayName
            },
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary
        )

        Text(
            text = stringResource(R.string.chord_fingering),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Text(
            text = shape.frets.joinToString("  ") { fret ->
                when {
                    fret < 0 -> "×"
                    fret == 0 -> "0"
                    else -> fret.toString()
                }
            },
            style = MaterialTheme.typography.bodyLarge
        )

        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center
        ) {
            ChordDiagram(
                shape = shape,
                modifier = Modifier.width(220.dp)
            )
        }

        if (shape.fingers.any { it != null }) {
            Text(
                text = stringResource(R.string.finger_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        if (shape.barres.isNotEmpty()) {
            Text(
                text = stringResource(R.string.barre_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@StringRes
private fun ChordQuality.labelResource(): Int =
    when (this) {
        ChordQuality.MAJOR -> R.string.quality_major
        ChordQuality.MINOR -> R.string.quality_minor
        ChordQuality.POWER_5 -> R.string.quality_power_5
        ChordQuality.MAJOR_6 -> R.string.quality_major_6
        ChordQuality.MINOR_6 -> R.string.quality_minor_6
        ChordQuality.DOMINANT_7 -> R.string.quality_dominant_7
        ChordQuality.MAJOR_7 -> R.string.quality_major_7
        ChordQuality.MINOR_7 -> R.string.quality_minor_7
        ChordQuality.DOMINANT_9 -> R.string.quality_dominant_9
        ChordQuality.MAJOR_9 -> R.string.quality_major_9
        ChordQuality.MINOR_9 -> R.string.quality_minor_9
        ChordQuality.SUS_2 -> R.string.quality_sus_2
        ChordQuality.SUS_4 -> R.string.quality_sus_4
        ChordQuality.ADD_9 -> R.string.quality_add_9
        ChordQuality.DIMINISHED -> R.string.quality_dim
        ChordQuality.AUGMENTED -> R.string.quality_aug
    }
