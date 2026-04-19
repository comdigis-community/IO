package com.comdigis.sampleapp.audio

import android.content.Context
import android.os.Looper
import androidx.annotation.MainThread
import com.comdigis.io.android.audio.Assemble
import com.comdigis.io.android.audio.AudioGraph
import com.comdigis.io.android.audio.AudioNode
import com.comdigis.io.android.audio.Binaural
import com.comdigis.io.android.audio.DistanceModel
import com.comdigis.io.android.audio.FileRenderer
import com.comdigis.io.android.audio.Listener
import com.comdigis.io.android.audio.NativeLoader
import com.comdigis.io.android.audio.Vector3
import java.util.concurrent.atomic.AtomicBoolean

class BinauralCoordinator(
    context: Context,
    contentsPath: String
) : AutoCloseable {

    private val source: FileRenderer
    private val connector: Binaural
    private val graph: AudioGraph
    private val destination: AudioNode
    private val assembler: Assemble
    private val listener: Listener
    private var lastListenerPosition = Vector3(0.0, 0.0, 0.0)
    private var lastListenerTimestamp = 0.0
    private var hasListenerState = false
    private var renderingStarted = false
    private val closed = AtomicBoolean(false)

    init {
        requireMainThread("BinauralCoordinator.init")
        NativeLoader.requireLoaded(context)

        var localAssembler: Assemble? = null
        var localGraph: AudioGraph? = null
        var localSource: FileRenderer? = null
        var localConnector: Binaural? = null
        var localListener: Listener? = null
        var localDestination: AudioNode? = null

        try {
            val createdAssembler = Assemble(Assemble.Rendering.LIVE)
            localAssembler = createdAssembler
            val createdGraph = createdAssembler.createAudioGraph()
            localGraph = createdGraph

            val createdSource = FileRenderer(contentsPath)
            createdSource.setLoopEnabled(true)
            localSource = createdSource

            val createdConnector = Binaural(BinauralDatabaseLoader.current())
            localConnector = createdConnector

            val createdListener = Listener(createdGraph)
            localListener = createdListener
            val createdDestination = createdGraph.destination()
            localDestination = createdDestination

            assembler = createdAssembler
            graph = createdGraph
            source = createdSource
            connector = createdConnector
            listener = createdListener
            destination = createdDestination

            configureSpatialSettings()
            graph.connect(source, connector)
            graph.connect(connector, destination)
            graph.startRendering()
            renderingStarted = true
        } catch (error: Throwable) {
            closeQuietly { localConnector?.close() }
            closeQuietly { localSource?.close() }
            closeQuietly { localDestination?.close() }
            closeQuietly { localGraph?.close() }
            closeQuietly { localAssembler?.close() }
            throw error
        }
    }

    fun play(afterSeconds: Double = 0.0) {
        requireMainThread("BinauralCoordinator.play")
        checkOpen()
        source.play(afterSeconds)
    }

    fun stop(afterSeconds: Double = 0.0) {
        requireMainThread("BinauralCoordinator.stop")
        checkOpen()
        source.stop(afterSeconds)
    }

    fun updateObjectPosition(position: Vector3) {
        requireMainThread("BinauralCoordinator.updateObjectPosition")
        checkOpen()
        connector.setPosition(position.x, position.y, position.z)
    }

    fun update(position: Vector3, forward: Vector3, up: Vector3, timestampSeconds: Double) {
        requireMainThread("BinauralCoordinator.update")
        checkOpen()
        listener.setPosition(position.x, position.y, position.z)
        listener.setForward(forward.x, forward.y, forward.z)
        listener.setUp(up.x, up.y, up.z)

        if (!hasListenerState) {
            listener.setVelocity(0.0, 0.0, 0.0)
            lastListenerPosition = position
            lastListenerTimestamp = timestampSeconds
            hasListenerState = true
            return
        }

        val delta = timestampSeconds - lastListenerTimestamp
        val velocity = if (delta <= 1e-6) {
            Vector3(0.0, 0.0, 0.0)
        } else {
            Vector3(
                (position.x - lastListenerPosition.x) / delta,
                (position.y - lastListenerPosition.y) / delta,
                (position.z - lastListenerPosition.z) / delta
            )
        }

        listener.setVelocity(velocity.x, velocity.y, velocity.z)
        lastListenerPosition = position
        lastListenerTimestamp = timestampSeconds
    }

    fun isPlayingOrScheduled(): Boolean {
        requireMainThread("BinauralCoordinator.isPlayingOrScheduled")
        return !closed.get() && source.isPlayingOrScheduled()
    }

    @MainThread
    override fun close() {
        requireMainThread("BinauralCoordinator.close")
        if (!closed.compareAndSet(false, true)) {
            return
        }
        closeQuietly { source.stop(0.0) }
        if (renderingStarted) {
            closeQuietly { graph.stopRendering() }
            renderingStarted = false
        }
        closeQuietly { connector.close() }
        closeQuietly { source.close() }
        closeQuietly { destination.close() }
        closeQuietly { graph.close() }
        closeQuietly { assembler.close() }
    }

    private fun configureSpatialSettings() {
        connector.setInnerRadius(5.0)
        connector.setOuterRadius(15.0)
        connector.setRollOff(4.5)
        connector.setCone(innerAngle = 40.0, outerAngle = 120.0, outerGain = 0.2)
        connector.setDistanceModel(DistanceModel.INVERSE)

        listener.setUp(0.0, 1.0, 0.0)
        listener.setForward(0.0, 0.0, -1.0)
        listener.setPosition(0.0, 0.0, 0.0)
        listener.setVelocity(0.0, 0.0, 0.0)
        listener.setDoppler(1.0)
        listener.setSpeedOfSound(343.0)
    }

    private inline fun closeQuietly(action: () -> Unit) {
        try {
            action()
        } catch (_: Exception) {
        }
    }

    private fun checkOpen() {
        check(!closed.get()) { "BinauralCoordinator is closed" }
    }

    private fun requireMainThread(scope: String) {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "$scope must be called from the main thread"
        }
    }
}
