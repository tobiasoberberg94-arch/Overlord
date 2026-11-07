plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val runNumber = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()

android {
    namespace = "de.overlord.tv"
    compileSdk = 35

    defaultConfig {
        applicationId = "de.overlord.tv"
        minSdk = 22
        targetSdk = 34
        versionCode = runNumber
        versionName = "1.0.$runNumber"
    }

    signingConfigs {
        create("overlord") {
            // Eigener, fest eingecheckter Schlüssel: so lassen sich neue APKs
            // ohne Deinstallation über alte Versionen installieren.
            // Eigener Schlüssel möglich über die Umgebungsvariablen unten.
            storeFile = file(System.getenv("OVERLORD_KEYSTORE") ?: "overlord.keystore")
            storePassword = System.getenv("OVERLORD_KEYSTORE_PASSWORD") ?: "overlord"
            keyAlias = System.getenv("OVERLORD_KEY_ALIAS") ?: "overlord"
            keyPassword = System.getenv("OVERLORD_KEY_PASSWORD") ?: "overlord"
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("overlord")
        }
        getByName("release") {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("overlord")
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}

dependencies {
    implementation("androidx.webkit:webkit:1.12.1")
}
