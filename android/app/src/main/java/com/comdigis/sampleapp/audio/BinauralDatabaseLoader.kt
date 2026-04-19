package com.comdigis.sampleapp.audio

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.comdigis.io.android.audio.BinauralDatabase
import java.util.concurrent.Executors

object BinauralDatabaseLoader {
    private val queue = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "binaural-db-loader").apply { isDaemon = true }
    }

    @Volatile
    private var database: BinauralDatabase? = null
    @Volatile
    private var isReady: Boolean = false
    @Volatile
    private var isPreloadInFlight: Boolean = false
    private val lock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val completions = mutableListOf<(Result<Boolean>) -> Unit>()

    fun current(): BinauralDatabase {
        return checkNotNull(database) { "Binaural database is not initialized. Call preload(...) first." }
    }

    fun preload(
        context: Context,
        hrtfDirectory: String? = null,
        completion: (Result<Boolean>) -> Unit
    ) {
        var shouldCallbackImmediately = false
        synchronized(lock) {
            if (isReady) {
                shouldCallbackImmediately = true
            } else {
                completions += completion
                if (!isPreloadInFlight) {
                    isPreloadInFlight = true
                } else {
                    return
                }
            }
        }
        if (shouldCallbackImmediately) {
            mainHandler.post { completion(Result.success(true)) }
            return
        }

        queue.execute {
            val resolvedDirectory = runCatching {
                hrtfDirectory ?: HrtfAssetInstaller.ensureInstalled(context)
            }.getOrElse { error ->
                finishPreload(Result.failure(error))
                return@execute
            }

            val instance = runCatching {
                synchronized(lock) {
                    database ?: BinauralDatabase(resolvedDirectory).also { created ->
                        database = created
                    }
                }
            }.getOrElse { error ->
                finishPreload(Result.failure(error))
                return@execute
            }

            instance.loadAsynchronously { error ->
                val result = when {
                    error == null && instance.isLoaded() -> {
                        synchronized(lock) {
                            isReady = true
                        }
                        Result.success(true)
                    }
                    else -> recoverWithSynchronousLoad(
                        current = instance,
                        resolvedDirectory = resolvedDirectory,
                        asyncFailure = error
                    )
                }
                finishPreload(result)
            }
        }
    }

    fun reset() {
        val instanceToClose = synchronized(lock) {
            val current = database
            database = null
            isReady = false
            isPreloadInFlight = false
            completions.clear()
            current
        }
        runCatching { instanceToClose?.close() }
    }

    private fun recoverWithSynchronousLoad(
        current: BinauralDatabase,
        resolvedDirectory: String,
        asyncFailure: Throwable?
    ): Result<Boolean> {
        return runCatching {
            val replacement = synchronized(lock) {
                if (database === current) {
                    runCatching { current.close() }
                    BinauralDatabase(resolvedDirectory).also { recreated ->
                        database = recreated
                    }
                } else {
                    database ?: BinauralDatabase(resolvedDirectory).also { recreated ->
                        database = recreated
                    }
                }
            }

            replacement.loadSynchronously()
            check(replacement.isLoaded()) {
                "Unable to preload HRTF database"
            }
            synchronized(lock) {
                isReady = true
            }
            true
        }.fold(
            onSuccess = { Result.success(it) },
            onFailure = { syncFailure ->
                val cause = asyncFailure?.let { prior ->
                    Exception(
                        "Async preload failed and sync recovery failed",
                        prior
                    ).also { wrapper ->
                        wrapper.addSuppressed(syncFailure)
                    }
                } ?: syncFailure
                Result.failure(cause)
            }
        )
    }

    private fun finishPreload(result: Result<Boolean>) {
        val localCompletions = synchronized(lock) {
            isPreloadInFlight = false
            if (result.isFailure) {
                isReady = false
            }
            val pending = completions.toList()
            completions.clear()
            pending
        }

        mainHandler.post {
            localCompletions.forEach { callback ->
                callback(result)
            }
        }
    }
}
