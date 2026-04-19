import java.net.URL
import java.security.MessageDigest
import java.util.Properties
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.TaskAction

plugins {
    alias(libs.plugins.android.library)
}

val metadataFile = layout.projectDirectory.file("io-android-community.properties")

val ioAndroidMetadata = providers.provider {
    if (!metadataFile.asFile.exists()) {
        throw GradleException("Missing metadata file: ${metadataFile.asFile.absolutePath}")
    }
    Properties().apply {
        metadataFile.asFile.inputStream().use(::load)
    }
}

val ioAndroidVersion = providers.provider {
    ioAndroidMetadata.get().getProperty("IO_ANDROID_VERSION")
        ?: throw GradleException("Missing IO_ANDROID_VERSION in ${metadataFile.asFile.absolutePath}")
}
val ioAndroidAarUrl = providers.provider {
    ioAndroidMetadata.get().getProperty("IO_ANDROID_AAR_URL")
        ?: throw GradleException("Missing IO_ANDROID_AAR_URL in ${metadataFile.asFile.absolutePath}")
}
val ioAndroidAarSha256 = providers.provider {
    ioAndroidMetadata.get().getProperty("IO_ANDROID_AAR_SHA256")
        ?: throw GradleException("Missing IO_ANDROID_AAR_SHA256 in ${metadataFile.asFile.absolutePath}")
}

val downloadedAar = layout.buildDirectory.file("download/IO-${ioAndroidVersion.get()}-community.aar")

abstract class DownloadAarTask : DefaultTask() {
    @get:Input
    abstract val sourceUrl: Property<String>

    @get:OutputFile
    abstract val outputFile: RegularFileProperty

    @TaskAction
    fun run() {
        val output = outputFile.get().asFile
        output.parentFile.mkdirs()
        URL(sourceUrl.get()).openStream().use { input ->
            output.outputStream().use { outputStream ->
                input.copyTo(outputStream)
            }
        }
    }
}

abstract class VerifyAarChecksumTask : DefaultTask() {
    @get:InputFile
    abstract val inputFile: RegularFileProperty

    @get:Input
    abstract val expectedSha256: Property<String>

    @TaskAction
    fun run() {
        val file = inputFile.get().asFile
        if (!file.exists()) {
            throw GradleException("Missing downloaded AAR: ${file.absolutePath}")
        }

        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }

        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        val expected = expectedSha256.get().trim().lowercase()
        if (expected.startsWith("REPLACE_WITH_")) {
            throw GradleException(
                "Placeholder checksum detected in io-android-community.properties. " +
                    "Update IO_ANDROID_AAR_SHA256 before building."
            )
        }
        if (actual != expected) {
            throw GradleException("AAR checksum mismatch. expected=$expected actual=$actual")
        }
    }
}

val downloadIoAndroidCommunityAar by tasks.registering(DownloadAarTask::class) {
    sourceUrl.set(ioAndroidAarUrl)
    outputFile.set(downloadedAar)
}

val verifyIoAndroidCommunityAar by tasks.registering(VerifyAarChecksumTask::class) {
    dependsOn(downloadIoAndroidCommunityAar)
    inputFile.set(downloadedAar)
    expectedSha256.set(ioAndroidAarSha256)
}

android {
    namespace = "com.comdigis.community.io.android.experimental"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        minSdk = 28

        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }

        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(verifyIoAndroidCommunityAar)
}

dependencies {
    api(files(downloadedAar).builtBy(verifyIoAndroidCommunityAar))
    implementation("androidx.annotation:annotation:1.9.1")
}
