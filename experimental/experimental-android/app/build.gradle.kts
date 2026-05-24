
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

abstract class SyncHrtfAssetsTask : DefaultTask() {
    @get:InputDirectory
    abstract val sourceDir: DirectoryProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @TaskAction
    fun executeSync() {
        project.copy {
            from(sourceDir)
            into(outputDir)
        }
    }
}

abstract class SyncDemoAudioAssetTask : DefaultTask() {
    @get:InputFile
    abstract val sourceFile: RegularFileProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @TaskAction
    fun executeSync() {
        project.copy {
            from(sourceFile)
            into(outputDir)
        }
    }
}

val generatedHrtfAssetsDir = layout.buildDirectory.dir("generated/assets/hrtf")
val syncHrtfAssets by tasks.registering(SyncHrtfAssetsTask::class) {
    sourceDir.set(rootProject.layout.projectDirectory.dir("../../database"))
    outputDir.set(generatedHrtfAssetsDir)
}
val generatedDemoAudioAssetsDir = layout.buildDirectory.dir("generated/assets/demo-audio")
val syncDemoAudioAsset by tasks.registering(SyncDemoAudioAssetTask::class) {
    sourceFile.set(rootProject.layout.projectDirectory.file("../../etc/voiceover_interactive_en.mp3"))
    outputDir.set(generatedDemoAudioAssetsDir)
}

android {
    namespace = "com.comdigis.sampleapp"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.comdigis.sampleapp"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        debug {
            isJniDebuggable = true
        }
        release {
            isMinifyEnabled = false
            isJniDebuggable = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

androidComponents {
    onVariants(selector().all()) { variant ->
        variant.sources.assets?.addGeneratedSourceDirectory(
            syncHrtfAssets
        ) { task ->
            task.outputDir
        }
        variant.sources.assets?.addGeneratedSourceDirectory(
            syncDemoAudioAsset
        ) { task ->
            task.outputDir
        }
    }
}

dependencies {
    implementation(project(":experimental"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
