package dev.mirinnano.guitartools.ui.metronome

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.mirinnano.guitartools.audio.MetronomeEngine

@Composable
fun MetronomeScreen(modifier: Modifier = Modifier) {
    var bpm by remember { mutableIntStateOf(120) }
    var playing by remember { mutableStateOf(false) }
    val engine = remember { MetronomeEngine() }

    DisposableEffect(Unit) {
        onDispose { engine.stop() }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("METRONOME")
        Text("$bpm", fontSize = 72.sp)
        Text("BPM")

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(-5, -1, 1, 5).forEach { delta ->
                Button(onClick = { bpm = (bpm + delta).coerceIn(30, 300) }) {
                    Text(if (delta > 0) "+$delta" else "$delta")
                }
            }
        }

        Button(
            modifier = Modifier.padding(top = 24.dp),
            onClick = {
                playing = !playing
                if (playing) engine.start { bpm } else engine.stop()
            }
        ) {
            Text(if (playing) "STOP" else "START")
        }
    }
}
