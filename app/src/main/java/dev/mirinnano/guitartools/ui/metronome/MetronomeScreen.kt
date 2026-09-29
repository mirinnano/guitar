package dev.mirinnano.guitartools.ui.metronome

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.mirinnano.guitartools.R
import dev.mirinnano.guitartools.audio.MetronomeConfig

private val TempoSteps = listOf(-5, -1, 1, 5)

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
        TempoCard(bpm = state.bpm)

        Slider(
            value = state.bpm.toFloat(),
            onValueChange = viewModel::setBpm,
            valueRange = MetronomeConfig.MIN_BPM.toFloat()..
                MetronomeConfig.MAX_BPM.toFloat(),
            modifier = Modifier.fillMaxWidth()
        )

        TempoStepButtons(
            onStep = viewModel::changeBpm
        )

        FilledTonalButton(
            onClick = viewModel::registerTempoTap,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                imageVector = Icons.Rounded.TouchApp,
                contentDescription = null
            )
            Text(
                text = stringResource(R.string.tap_tempo),
                modifier = Modifier.padding(start = 8.dp)
            )
        }

        BeatSettingsCard(
            beatsPerBar = state.beatsPerBar,
            accentFirstBeat = state.accentFirstBeat,
            onBeatsPerBarChange = viewModel::setBeatsPerBar,
            onAccentChange = viewModel::setAccentFirstBeat
        )

        if (state.playbackFailed) {
            PlaybackError(
                onDismiss = viewModel::dismissPlaybackError
            )
        }

        Button(
            onClick = viewModel::togglePlayback,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                imageVector = if (state.isPlaying) {
                    Icons.Rounded.Pause
                } else {
                    Icons.Rounded.PlayArrow
                },
                contentDescription = null
            )
            Text(
                text = stringResource(
                    if (state.isPlaying) R.string.stop else R.string.start
                ),
                modifier = Modifier.padding(start = 8.dp)
            )
        }
    }
}

@Composable
private fun TempoCard(bpm: Int) {
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
                text = bpm.toString(),
                style = MaterialTheme.typography.displayLarge
            )
            Text(
                text = stringResource(R.string.bpm),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun TempoStepButtons(
    onStep: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        TempoSteps.forEach { step ->
            FilledTonalButton(
                onClick = { onStep(step) },
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = if (step > 0) "+$step" else step.toString()
                )
            }
        }
    }
}

@Composable
private fun BeatSettingsCard(
    beatsPerBar: Int,
    accentFirstBeat: Boolean,
    onBeatsPerBarChange: (Int) -> Unit,
    onAccentChange: (Boolean) -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = stringResource(R.string.beat_settings),
                style = MaterialTheme.typography.titleMedium
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = stringResource(R.string.beats_per_bar),
                    modifier = Modifier.weight(1f)
                )

                FilledTonalButton(
                    onClick = {
                        onBeatsPerBarChange(beatsPerBar - 1)
                    }
                ) {
                    Text("−")
                }

                Text(
                    text = beatsPerBar.toString(),
                    style = MaterialTheme.typography.titleLarge
                )

                FilledTonalButton(
                    onClick = {
                        onBeatsPerBarChange(beatsPerBar + 1)
                    }
                ) {
                    Text("+")
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(
                    modifier = Modifier.weight(1f)
                ) {
                    Text(
                        text = stringResource(R.string.accent_first_beat)
                    )
                    Text(
                        text = stringResource(
                            R.string.accent_first_beat_description
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Switch(
                    checked = accentFirstBeat,
                    onCheckedChange = onAccentChange
                )
            }
        }
    }
}

@Composable
private fun PlaybackError(
    onDismiss: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.metronome_error),
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.weight(1f)
            )
            TextButton(
                onClick = onDismiss
            ) {
                Text("OK")
            }
        }
    }
}
