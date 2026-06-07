import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")

// Validate that key.properties exists before any release build executes.
// This check runs after the task graph is resolved, so debug builds are unaffected.
gradle.taskGraph.whenReady {
    val hasReleaseBuild = allTasks.any { task ->
        task.name == "assembleRelease" || task.name == "bundleRelease"
    }
    if (hasReleaseBuild && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "\n\n" +
            "Release signing requires android/key.properties.\n" +
            "Debug builds do not require it.\n" +
            "See docs/deployment/mobile_release_runbook.md for setup instructions.\n",
        )
    }
}

android {
    namespace = "com.lexrush.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    if (keystorePropertiesFile.exists()) {
        val keystoreProperties = Properties().apply {
            load(FileInputStream(keystorePropertiesFile))
        }
        signingConfigs {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.lexrush.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            // signingConfig is only set when key.properties is present.
            // If it is absent, the gradle.taskGraph.whenReady guard above
            // throws a clear error before any release task executes.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
