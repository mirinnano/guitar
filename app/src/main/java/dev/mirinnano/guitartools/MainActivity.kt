package dev.mirinnano.guitartools

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import dev.mirinnano.guitartools.ui.GuitarToolsApp
import dev.mirinnano.guitartools.ui.theme.GuitarToolsTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            GuitarToolsTheme {
                GuitarToolsApp()
            }
        }
    }
}
