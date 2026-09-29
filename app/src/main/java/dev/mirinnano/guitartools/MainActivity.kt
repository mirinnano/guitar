package dev.mirinnano.guitartools

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.mirinnano.guitartools.ui.GuitarToolsApp
import dev.mirinnano.guitartools.ui.theme.GuitarToolsTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            GuitarToolsTheme {
                GuitarToolsApp()
            }
        }
    }
}
