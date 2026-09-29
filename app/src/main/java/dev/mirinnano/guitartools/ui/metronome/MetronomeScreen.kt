package dev.mirinnano.guitartools.ui.metronome

import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun MetronomeScreen(
    modifier: Modifier = Modifier,
    viewModel: MetronomeViewModel = viewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = state.bpm.toString(),
                    style = MaterialTheme.typography.displayLarge
                )
                Text(
                    text = "BPM",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Slider(
            value = state.bpm.toFloat(),
            onValueChange = { viewModel.setBpm(it.toInt()) },
            valueRange = 30f..300f,
            modifier = Modifier.fillMaxWidth()
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf(-5, -1, 1, 5).forEach { delta ->
                FilledTonalButton(
                    onClick = { viewModel.changeBpm(delta) },
                    modifier = Modifier.weight(1f)
                ) {
                    Text(if (delta > 0) "+$delta" else "$delta")
                }
            }
        }

        FilledTonalButton(
            onClick = viewModel::tapTempo,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                imageVector = Icons.Rounded.TouchApp,
                contentDescription = null
            )
            Text(
                text = "Tap tempo",
                modifier = Modifier.padding(start = 8.dp)
            )
        }

        Card(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "Beat",
                    style = MaterialTheme.typography.titleMedium
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text("Beats per bar")
                    FilledTonalButton(
                        onClick = { viewModel.setBeatsPerBar(state.beatsPerBar - 1) }
                    ) {
                        Text("−")
                    }
                    Text(
                        text = state.beatsPerBar.toString(),
                        style = MaterialTheme.typography.titleLarge
                    )
                    FilledTonalButton(
                        onClick = { viewModel.setBeatsPerBar(state.beatsPerBar + 1) }
                    ) {
                        Text("+")
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Accent first beat")
                        Text(
                            text = "Use a higher click on beat one",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Switch(
                        checked = state.accentFirstBeat,
                        onCheckedChange = viewModel::setAccentFirstBeat
                    )
                }
            }
        }

        Button(
            onClick = viewModel::togglePlayback,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                imageVector = if (state.isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                contentDescription = null
            )
            Text(
                text = if (state.isPlaying) "Stop" else "Start",
                modifier = Modifier.padding(start = 8.dp)
            )
        }
    }
}
