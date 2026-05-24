package com.comdigis.sampleapp

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.comdigis.sampleapp.ui.theme.SampleAppTheme
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

@Composable
fun PlayerScreen(
    enabled: Boolean,
    playing: Boolean,
    status: String,
    onListenerOrientationChanged: (yawRadians: Double, pitchRadians: Double) -> Unit,
    onPlay: () -> Boolean,
    onStop: () -> Unit
) {
    var yaw by remember { mutableFloatStateOf(0f) }
    var pitch by remember { mutableFloatStateOf(0f) }
    val maxPitch = ((PI / 2.0) - 0.08).toFloat()
    val controlTextStyle = TextStyle(fontSize = 16.sp)

    LaunchedEffect(yaw, pitch) {
        onListenerOrientationChanged(yaw.toDouble(), pitch.toDouble())
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        ListenerOrientationSphere(
            modifier = Modifier.align(Alignment.Center),
            enabled = enabled,
            yaw = yaw,
            pitch = pitch,
            onOrientationChange = { nextYaw, nextPitch ->
                yaw = nextYaw
                pitch = max(-maxPitch, min(maxPitch, nextPitch))
            }
        )

        if (!enabled) {
            Text(
                text = status,
                color = Color.White,
                style = controlTextStyle,
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(top = 305.dp)
            )
        }

        Button(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 72.dp),
            enabled = enabled,
            onClick = {
                if (playing) {
                    onStop()
                } else {
                    onPlay()
                }
            }
        ) {
            Text(
                text = if (playing) "Stop" else "Play",
                style = controlTextStyle
            )
        }
    }
}

@Composable
private fun ListenerOrientationSphere(
    enabled: Boolean,
    yaw: Float,
    pitch: Float,
    onOrientationChange: (yaw: Float, pitch: Float) -> Unit,
    modifier: Modifier = Modifier
) {
    val sensitivity = 0.005f
    val latitudeSteps = 12
    val longitudeSteps = 18
    val currentYaw by rememberUpdatedState(yaw)
    val currentPitch by rememberUpdatedState(pitch)

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .pointerInput(enabled) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    if (!enabled) return@detectDragGestures
                    val nextYaw = currentYaw + (dragAmount.x * sensitivity)
                    val nextPitch = currentPitch - (dragAmount.y * sensitivity)
                    onOrientationChange(nextYaw, nextPitch)
                }
            }
    ) {
        val radius = min(size.width, size.height) * 0.85f
        val center = Offset(size.width / 2f, size.height / 2f)
        val stroke = Stroke(width = 1.2f)
        val cameraDistance = 3.2f
        val projection = radius * 0.95f

        val cy = cos(yaw)
        val sy = sin(yaw)
        val cx = cos(pitch)
        val sx = sin(pitch)

        fun rotateAndProject(point: Vec3): Pair<Offset, Float> {
            val x1 = (point.x * cy) + (point.z * sy)
            val z1 = (-point.x * sy) + (point.z * cy)

            val y2 = (point.y * cx) - (z1 * sx)
            val z2 = (point.y * sx) + (z1 * cx)

            val depth = cameraDistance - z2
            val scale = projection / max(0.25f, depth)

            return Offset(
                x = center.x + (x1 * scale),
                y = center.y - (y2 * scale)
            ) to z2
        }

        for (lat in 0..latitudeSteps) {
            val phi = -PI.toFloat() / 2f + (lat.toFloat() / latitudeSteps.toFloat()) * PI.toFloat()
            var previous: Pair<Offset, Float>? = null

            for (lon in 0..longitudeSteps) {
                val theta = (lon.toFloat() / longitudeSteps.toFloat()) * (PI.toFloat() * 2f)
                val point = Vec3(
                    x = cos(phi) * cos(theta),
                    y = sin(phi),
                    z = cos(phi) * sin(theta)
                )
                val projected = rotateAndProject(point)

                previous?.let { last ->
                    val lineDepth = (last.second + projected.second) * 0.5f
                    if (lineDepth >= 0f) {
                        drawLine(
                            color = Color.White,
                            start = last.first,
                            end = projected.first,
                            strokeWidth = stroke.width
                        )
                    }
                }

                previous = projected
            }
        }

        for (lon in 0 until longitudeSteps) {
            val theta = (lon.toFloat() / longitudeSteps.toFloat()) * (PI.toFloat() * 2f)
            var previous: Pair<Offset, Float>? = null

            for (lat in 0..latitudeSteps) {
                val phi = -PI.toFloat() / 2f + (lat.toFloat() / latitudeSteps.toFloat()) * PI.toFloat()
                val point = Vec3(
                    x = cos(phi) * cos(theta),
                    y = sin(phi),
                    z = cos(phi) * sin(theta)
                )
                val projected = rotateAndProject(point)

                previous?.let { last ->
                    val lineDepth = (last.second + projected.second) * 0.5f
                    if (lineDepth >= 0f) {
                        drawLine(
                            color = Color.White,
                            start = last.first,
                            end = projected.first,
                            strokeWidth = stroke.width
                        )
                    }
                }

                previous = projected
            }
        }
    }
}

private data class Vec3(
    val x: Float,
    val y: Float,
    val z: Float
)

@Preview(showBackground = true)
@Composable
private fun PlayerScreenPreview() {
    SampleAppTheme {
        PlayerScreen(
            enabled = false,
            playing = false,
            status = "Loading database...",
            onListenerOrientationChanged = { _, _ -> },
            onPlay = { true },
            onStop = {}
        )
    }
}
