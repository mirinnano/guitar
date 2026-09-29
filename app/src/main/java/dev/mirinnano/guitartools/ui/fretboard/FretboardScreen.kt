package dev.mirinnano.guitartools.ui.fretboard

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.mirinnano.guitartools.music.Fretboard
import dev.mirinnano.guitartools.music.Tuning

@Composable
fun FretboardScreen(modifier: Modifier = Modifier) {
    val tuning = Tuning.Standard

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

        Card {
            Column(
                modifier = Modifier
                    .horizontalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                    Text("String", modifier = Modifier.padding(end = 8.dp))
                    (0..12).forEach { fret ->
                        Text(
                            text = fret.toString(),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                tuning.strings.reversed().forEach { string ->
                    Row(horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                        Text(
                            text = string.label,
                            style = MaterialTheme.typography.labelLarge,
                            modifier = Modifier.padding(end = 8.dp)
                        )

                        (0..12).forEach { fretNumber ->
                            val position = Fretboard.position(string, fretNumber)
                            Text(
                                text = position.note.displayName,
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                    }
                }
            }
        }

        Text(
            text = "Showing frets 0–12. Standard tuning.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
