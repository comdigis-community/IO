package com.comdigis.sampleapp.audio

import android.content.Context
import java.io.File

object HrtfAssetInstaller {
    private const val HRTF_ASSET_DIRECTORY = "hrtf"
    private const val HRTF_FILE_PREFIX = "IRC_Composite"
    private const val HRTF_INDEX_FILE = "Composite.wav"

    fun ensureInstalled(context: Context): String {
        val targetDirectory = File(context.filesDir, HRTF_ASSET_DIRECTORY)
        val hasHrtfDirectory = context.assets
            .list(HRTF_ASSET_DIRECTORY)
            ?.filter { it.isNotBlank() }
            ?.isNotEmpty() == true

        if (hasHrtfDirectory) {
            copyDirectoryIfNeeded(context, HRTF_ASSET_DIRECTORY, targetDirectory)
        } else {
            copyFlatHrtfAssets(context, targetDirectory)
        }

        return targetDirectory.absolutePath
    }

    private fun copyDirectoryIfNeeded(context: Context, assetPath: String, destination: File) {
        val children = context.assets.list(assetPath)?.filter { it.isNotBlank() }.orEmpty()

        if (children.isEmpty()) {
            if (!destination.exists()) {
                error("HRTF asset directory is missing: $assetPath")
            }
            return
        }

        if (!destination.exists() && !destination.mkdirs()) {
            error("Unable to create HRTF directory: ${destination.absolutePath}")
        }

        for (name in children) {
            val childAssetPath = "$assetPath/$name"
            val childDestination = File(destination, name)
            val grandChildren = context.assets.list(childAssetPath)?.filter { it.isNotBlank() }.orEmpty()

            if (grandChildren.isEmpty()) {
                if (childDestination.exists()) {
                    continue
                }

                context.assets.open(childAssetPath).use { input ->
                    childDestination.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            } else {
                copyDirectoryIfNeeded(context, childAssetPath, childDestination)
            }
        }
    }

    private fun copyFlatHrtfAssets(context: Context, destination: File) {
        val rootEntries = context.assets.list("")?.filter { it.isNotBlank() }.orEmpty()
        val hrtfEntries = rootEntries.filter { name ->
            name == HRTF_INDEX_FILE || name.startsWith(HRTF_FILE_PREFIX)
        }

        if (hrtfEntries.isEmpty()) {
            error(
                "HRTF assets are missing. Neither '$HRTF_ASSET_DIRECTORY/' nor flat HRTF files were found in APK assets."
            )
        }

        if (!destination.exists() && !destination.mkdirs()) {
            error("Unable to create HRTF directory: ${destination.absolutePath}")
        }

        for (name in hrtfEntries) {
            val output = File(destination, name)
            if (output.exists()) {
                continue
            }

            context.assets.open(name).use { input ->
                output.outputStream().use { sink ->
                    input.copyTo(sink)
                }
            }
        }
    }
}
