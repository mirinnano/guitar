package dev.mirinnano.guitartools.ui.chords

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
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.music.ChordQuality
import dev.mirinnano.guitartools.music.CommonChords
import dev.mirinnano.guitartools.ui.components.ChordDiagram

@Composable
fun ChordsScreen(modifier: Modifier = Modifier) {
    var query by remember { mutableStateOf("") }
    var selectedQuality by remember { mutableStateOf<ChordQuality?>(null) }

    val chords = remember(query, selectedQuality) {
        CommonChords.all.filter { shape ->
            val matchesSearch =
                query.isBlank() || shape.name.contains(query, ignoreCase = true)
            val matchesQuality =
                selectedQuality == null || shape.chord.quality == selectedQuality

            matchesSearch && matchesQuality
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            label = { Text("Search chords") },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Rounded.Search,
                    contentDescription = null
                )
            }
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = selectedQuality == null,
                onClick = { selectedQuality = null },
                label = { Text("All") }
            )

            ChordQuality.entries.forEach { quality ->
                FilterChip(
                    selected = selectedQuality == quality,
                    onClick = { selectedQuality = quality },
                    label = { Text(quality.displayName) }
                )
            }
        }

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(
                items = chords,
                key = { it.name }
            ) { shape ->
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
                                text = "Finger numbers are shown below the diagram.",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }

                        ChordDiagram(
                            shape = shape,
                            modifier = Modifier.width(156.dp)
                        )
                    }
                }
            }
        }
    }
}
