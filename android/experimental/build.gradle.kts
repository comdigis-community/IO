import java.util.Properties
import org.gradle.api.GradleException

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

dependencies {
    api("com.comdigis.io:io-android-community:${ioAndroidVersion.get()}@aar")
    implementation("androidx.annotation:annotation:1.9.1")
}
