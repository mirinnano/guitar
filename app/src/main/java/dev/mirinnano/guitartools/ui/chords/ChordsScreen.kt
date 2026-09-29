package dev.mirinnano.guitartools.ui.chords

import androidx.annotation.StringRes
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.music.ChordQuality
import dev.mirinnano.guitartools.music.ChordShape
import dev.mirinnano.guitartools.music.CommonChords
import dev.mirinnano.guitartools.ui.components.ChordDiagram

@Composable
fun ChordsScreen(
    modifier: Modifier = Modifier
) {
    var query by remember { mutableStateOf("") }
    var selectedQuality by remember {
        mutableStateOf<ChordQuality?>(null)
    }

    val visibleChords = remember(query, selectedQuality) {
        CommonChords.all.filter { shape ->
            matchesFilter(
                shape = shape,
                query = query,
                quality = selectedQuality
            )
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
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
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(
                items = visibleChords,
                key = { it.name }
            ) { shape ->
                ChordCard(shape)
            }
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
private fun ChordCard(
    shape: ChordShape
) {
    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = shape.name,
                    style = MaterialTheme.typography.headlineMedium
                )

                Text(
                    text = shape.chord.notes.joinToString(" · ") {
                        it.displayName
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary
                )

                Text(
                    text = shape.frets.joinToString("  ") { fret ->
                        when {
                            fret < 0 -> "×"
                            fret == 0 -> "0"
                            else -> fret.toString()
                        }
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(
                    text = stringResource(R.string.finger_hint),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                if (shape.barres.isNotEmpty()) {
                    Text(
                        text = stringResource(R.string.barre_hint),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            ChordDiagram(
                shape = shape,
                modifier = Modifier.width(156.dp)
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
        ChordQuality.DOMINANT_7 -> R.string.quality_dominant_7
        ChordQuality.MAJOR_7 -> R.string.quality_major_7
        ChordQuality.MINOR_7 -> R.string.quality_minor_7
        ChordQuality.SUS_2 -> R.string.quality_sus_2
        ChordQuality.SUS_4 -> R.string.quality_sus_4
        ChordQuality.ADD_9 -> R.string.quality_add_9
        ChordQuality.DIMINISHED -> R.string.quality_dim
        ChordQuality.AUGMENTED -> R.string.quality_aug
    }
