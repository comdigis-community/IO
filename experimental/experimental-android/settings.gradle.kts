import java.util.Properties

pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    val metadataFile = file("experimental/io-android-community.properties")
    val ioAndroidVersion = Properties().apply {
        if (!metadataFile.exists()) {
            throw GradleException("Missing metadata file: ${metadataFile.absolutePath}")
        }
        metadataFile.inputStream().use(::load)
    }.getProperty("IO_ANDROID_VERSION")
        ?: throw GradleException("Missing IO_ANDROID_VERSION in ${metadataFile.absolutePath}")

    repositories {
        google()
        mavenCentral()

        ivy {
            name = "IoCommunityReleases"
            url = uri("https://github.com/comdigis-community/IO/releases/download")
            patternLayout {
                artifact("$ioAndroidVersion/IO-$ioAndroidVersion-community.[ext]")
            }
            metadataSources {
                artifact()
            }
            content {
                includeGroup("com.comdigis.io")
            }
        }
    }
}

rootProject.name = "SampleApp"
include(":app")
include(":experimental")
