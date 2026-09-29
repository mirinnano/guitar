package dev.mirinnano.guitartools.ui.chords

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.mirinnano.guitartools.music.CommonChords

@Composable
fun ChordsScreen(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(20.dp)
    ) {
        Text("CHORDS", fontSize = 28.sp)
        LazyColumn {
            items(CommonChords.all) { chord ->
                Row(modifier = Modifier.padding(vertical = 14.dp)) {
                    Text(chord.name, fontSize = 24.sp, modifier = Modifier.weight(1f))
                    Text(chord.frets.joinToString("  ") { if (it < 0) "X" else it.toString() })
                }
                HorizontalDivider()
            }
        }
    }
}
