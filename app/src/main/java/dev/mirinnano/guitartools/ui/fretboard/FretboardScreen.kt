package dev.mirinnano.guitartools.ui.fretboard

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.music.Tuning
import dev.mirinnano.guitartools.ui.components.FretboardDiagram

@Composable
fun FretboardScreen(modifier: Modifier = Modifier) {
    val tuning = Tuning.Standard
    var highlightedNote by remember { mutableStateOf<Note?>(null) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = tuning.name,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Text(
            text = "Highlight note",
            style = MaterialTheme.typography.labelLarge
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FilterChip(
                selected = highlightedNote == null,
                onClick = { highlightedNote = null },
                label = { Text("All") }
            )

            Note.entries.forEach { note ->
                FilterChip(
                    selected = highlightedNote == note,
                    onClick = { highlightedNote = note },
                    label = { Text(note.displayName) }
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            FretboardDiagram(
                tuning = tuning,
                maxFret = 12,
                highlightedNote = highlightedNote,
                modifier = Modifier.padding(12.dp)
            )
        }

        Text(
            text = "Frets 0–12 · Standard tuning",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
