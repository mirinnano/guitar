package dev.mirinnano.guitartools.ui.fretboard

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.mirinnano.guitartools.music.Note
import dev.mirinnano.guitartools.music.Tuning

@Composable
fun FretboardScreen(modifier: Modifier = Modifier) {
    val standard = Tuning.Standard

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(20.dp)
    ) {
        Text("FRETBOARD", fontSize = 28.sp)
        Column(
            modifier = Modifier
                .padding(top = 20.dp)
                .horizontalScroll(rememberScrollState())
        ) {
            Row {
                Text("    ", modifier = Modifier.padding(6.dp))
                (0..12).forEach { fret ->
                    Text(fret.toString().padStart(3), modifier = Modifier.padding(6.dp))
                }
            }

            standard.strings.reversed().forEach { string ->
                Row {
                    Text(string.label.padEnd(4), modifier = Modifier.padding(6.dp))
                    (0..12).forEach { fret ->
                        val note = Note.fromMidi(string.midi + fret)
                        Text(note.displayName.padStart(3), modifier = Modifier.padding(6.dp))
                    }
                }
            }
        }
    }
}
