package com.comdigis.sampleapp

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.comdigis.io.android.audio.Vector3
import com.comdigis.sampleapp.audio.BinauralCoordinator
import com.comdigis.sampleapp.audio.BinauralDatabaseLoader
import com.comdigis.sampleapp.ui.theme.SampleAppTheme
import java.io.File
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

class MainActivity : ComponentActivity() {

    private var coordinator: BinauralCoordinator? = null
    private var uiState by mutableStateOf(UiState.loading())
    private var destroyed = false
    private var initSessionId: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            SampleAppTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    PlayerScreen(
                        enabled = uiState.isReady,
                        playing = uiState.isPlaying,
                        status = uiState.status,
                        modifier = Modifier.padding(innerPadding),
                        onObjectPositionChanged = { azimuthDegrees, elevationDegrees, distanceMeters ->
                            applyObjectPosition(azimuthDegrees, elevationDegrees, distanceMeters)
                        },
                        onPlay = { play() },
                        onStop = { stop() }
                    )
                }
            }
        }

        preloadAndBuildCoordinator()
    }

    override fun onStart() {
        super.onStart()
        if (!destroyed && coordinator == null && !uiState.isReady) {
            preloadAndBuildCoordinator()
        }
    }

    override fun onStop() {
        if (!isChangingConfigurations) {
            stop()
            uiState = uiState.copy(isPlaying = false, status = if (uiState.isReady) "Stopped" else uiState.status)
        }
        super.onStop()
    }

    override fun onDestroy() {
        destroyed = true
        initSessionId += 1
        uiState = uiState.copy(isPlaying = false)
        releaseCoordinator()
        if (!isChangingConfigurations) {
            BinauralDatabaseLoader.reset()
        }
        super.onDestroy()
    }

    private fun preloadAndBuildCoordinator() {
        if (destroyed) {
            return
        }

        initSessionId += 1
        val sessionId = initSessionId
        uiState = UiState.loading()
        BinauralDatabaseLoader.preload(this) { result ->
            if (sessionId != initSessionId || destroyed || isFinishing || isDestroyed) {
                return@preload
            }

            result.onFailure { error ->
                val message = error.message ?: "Unable to preload HRTF database"
                Log.e(TAG, "HRTF preload failed", error)
                uiState = UiState.error(message)
            }

            result.onSuccess { loaded ->
                if (!loaded) {
                    uiState = UiState.error("Unable to preload HRTF database")
                    return@onSuccess
                }

                val audioPath = runCatching { copyAssetToFilesDir(DEMO_AUDIO_ASSET) }
                    .getOrElse { error ->
                        uiState = UiState.error(
                            error.message ?: "Unable to prepare demo audio asset"
                        )
                        return@onSuccess
                    }

                val createdCoordinator = runCatching {
                    BinauralCoordinator(
                        context = this,
                        contentsPath = audioPath
                    )
                }.getOrElse { error ->
                    Log.e(TAG, "Coordinator initialization failed", error)
                    uiState = UiState.error(error.message ?: "Native initialization failed")
                    return@onSuccess
                }

                releaseCoordinator()
                coordinator = createdCoordinator
                applyObjectPosition(
                    azimuthDegrees = DEFAULT_AZIMUTH_DEGREES,
                    elevationDegrees = DEFAULT_ELEVATION_DEGREES,
                    distanceMeters = DEFAULT_DISTANCE_METERS
                )
                uiState = UiState.ready()
            }
        }
    }

    private fun play(): Boolean {
        val current = coordinator
        if (current == null) {
            uiState = uiState.copy(
                isReady = false,
                isPlaying = false,
                status = "Coordinator is not initialized"
            )
            return false
        }

        return runCatching {
            current.play(afterSeconds = 0.0)
            val playing = current.isPlayingOrScheduled()
            uiState = uiState.copy(isPlaying = playing, status = "Playing")
            playing
        }.getOrElse { error ->
            Log.e(TAG, "Play failed", error)
            uiState = uiState.copy(isPlaying = false, status = error.message ?: "play failed")
            false
        }
    }

    private fun stop() {
        val current = coordinator ?: return
        runCatching {
            current.stop(afterSeconds = 0.0)
            val stillPlaying = current.isPlayingOrScheduled()
            uiState = uiState.copy(isPlaying = stillPlaying, status = "Stopped")
        }.onFailure { error ->
            Log.e(TAG, "Stop failed", error)
            uiState = uiState.copy(isPlaying = false, status = error.message ?: "stop failed")
        }
    }

    private fun applyObjectPosition(
        azimuthDegrees: Float,
        elevationDegrees: Float,
        distanceMeters: Float
    ) {
        val current = coordinator ?: return
        val azimuthRadians = azimuthDegrees.toDouble() * PI / 180.0
        val elevationRadians = elevationDegrees.toDouble() * PI / 180.0
        val radius = distanceMeters.toDouble()
        val cosElevation = cos(elevationRadians)
        val position = Vector3(
            x = sin(azimuthRadians) * cosElevation * radius,
            y = sin(elevationRadians) * radius,
            z = -cos(azimuthRadians) * cosElevation * radius
        )
        current.updateObjectPosition(position)
    }

    private fun releaseCoordinator() {
        val current = coordinator ?: return
        coordinator = null
        runCatching { current.close() }
            .onFailure { error -> Log.w(TAG, "Coordinator close failed", error) }
    }

    private fun copyAssetToFilesDir(assetName: String): String {
        val target = File(filesDir, assetName)
        if (target.exists()) {
            return target.absolutePath
        }

        assets.open(assetName).use { input ->
            target.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        return target.absolutePath
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val DEMO_AUDIO_ASSET = "voiceover_en.wav"
        private const val DEFAULT_AZIMUTH_DEGREES = 0f
        private const val DEFAULT_ELEVATION_DEGREES = 0f
        private const val DEFAULT_DISTANCE_METERS = 2.5f
    }
}

private data class UiState(
    val isReady: Boolean,
    val isPlaying: Boolean,
    val status: String
) {
    companion object {
        fun loading(): UiState = UiState(
            isReady = false,
            isPlaying = false,
            status = "Loading HRTF..."
        )

        fun ready(): UiState = UiState(
            isReady = true,
            isPlaying = false,
            status = "Ready"
        )

        fun error(message: String): UiState = UiState(
            isReady = false,
            isPlaying = false,
            status = message
        )
    }
}

@Composable
private fun PlayerScreen(
    enabled: Boolean,
    playing: Boolean,
    status: String,
    modifier: Modifier = Modifier,
    onObjectPositionChanged: (azimuthDegrees: Float, elevationDegrees: Float, distanceMeters: Float) -> Unit,
    onPlay: () -> Boolean,
    onStop: () -> Unit
) {
    var azimuthDegrees by remember { mutableFloatStateOf(0f) }
    var elevationDegrees by remember { mutableFloatStateOf(0f) }
    var distanceMeters by remember { mutableFloatStateOf(2.5f) }

    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(text = "Azimuth: ${azimuthDegrees.toInt()}°", style = MaterialTheme.typography.bodySmall)
        Slider(
            modifier = Modifier.fillMaxWidth(0.8f),
            enabled = enabled,
            value = azimuthDegrees,
            valueRange = -180f..180f,
            onValueChange = { value ->
                azimuthDegrees = value
                onObjectPositionChanged(azimuthDegrees, elevationDegrees, distanceMeters)
            }
        )

        Text(text = "Elevation: ${elevationDegrees.toInt()}°", style = MaterialTheme.typography.bodySmall)
        Slider(
            modifier = Modifier.fillMaxWidth(0.8f),
            enabled = enabled,
            value = elevationDegrees,
            valueRange = -80f..80f,
            onValueChange = { value ->
                elevationDegrees = value
                onObjectPositionChanged(azimuthDegrees, elevationDegrees, distanceMeters)
            }
        )

        Text(text = "Distance: ${"%.1f".format(distanceMeters)} m", style = MaterialTheme.typography.bodySmall)
        Slider(
            modifier = Modifier.fillMaxWidth(0.8f),
            enabled = enabled,
            value = distanceMeters,
            valueRange = 0.5f..8f,
            onValueChange = { value ->
                distanceMeters = value
                onObjectPositionChanged(azimuthDegrees, elevationDegrees, distanceMeters)
            }
        )

        Spacer(modifier = Modifier.height(12.dp))

        Button(
            enabled = enabled,
            onClick = {
                if (playing) {
                    onStop()
                } else {
                    onPlay()
                }
            }
        ) {
            Text(if (playing) "Stop" else "Play")
        }

        Text(text = status, style = MaterialTheme.typography.bodySmall)
    }
}

@Preview(showBackground = true)
@Composable
private fun PlayerScreenPreview() {
    SampleAppTheme {
        PlayerScreen(
            enabled = true,
            playing = false,
            status = "Ready",
            onObjectPositionChanged = { _, _, _ -> },
            onPlay = { true },
            onStop = {}
        )
    }
}
