package com.comdigis.sampleapp

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.comdigis.io.android.audio.Vector3
import com.comdigis.sampleapp.audio.BinauralCoordinator
import com.comdigis.sampleapp.audio.BinauralDatabaseLoader
import com.comdigis.sampleapp.ui.theme.SampleAppTheme
import java.io.File
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
                PlayerScreen(
                    enabled = uiState.isReady,
                    playing = uiState.isPlaying,
                    status = uiState.status,
                    onListenerOrientationChanged = { yawRadians, pitchRadians ->
                        applyListenerOrientation(yawRadians, pitchRadians)
                    },
                    onPlay = { play() },
                    onStop = { stop() }
                )
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

        // Preload the HRTF database before creating the live graph so the binaural
        // node can be initialized with a ready spatial dataset.
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
                applyObjectPosition()
                applyListenerOrientation(yawRadians = 0.0, pitchRadians = 0.0)
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

    private fun applyObjectPosition() {
        val current = coordinator ?: return
        // Place the demo source in front of the listener at a fixed distance.
        val position = Vector3(
            x = 0.0,
            y = 0.0,
            z = DEFAULT_DISTANCE_METERS.toDouble()
        )
        current.updateObjectPosition(position)
    }

    private fun applyListenerOrientation(yawRadians: Double, pitchRadians: Double) {
        val current = coordinator ?: return
        // Convert the UI yaw/pitch controls into the forward vector used by the
        // audio listener. Position stays fixed for this sample.
        val forward = directionFromYawPitch(yawRadians = yawRadians, pitchRadians = pitchRadians)
        current.update(
            position = Vector3(0.0, 0.0, 0.0),
            forward = forward,
            up = Vector3(0.0, 1.0, 0.0),
            timestampSeconds = System.nanoTime() / 1_000_000_000.0
        )
    }

    private fun directionFromYawPitch(yawRadians: Double, pitchRadians: Double): Vector3 {
        val cosPitch = cos(pitchRadians)
        return Vector3(
            x = sin(yawRadians) * cosPitch,
            y = sin(pitchRadians),
            z = cos(yawRadians) * cosPitch
        )
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
        private const val DEMO_AUDIO_ASSET = "voiceover_interactive_en.mp3"
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
            status = "Loading database..."
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
