import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Glance (the home-screen widget) compiles Compose down to RemoteViews; this
    // plugin is the only reason Compose appears in an otherwise all-Flutter app.
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties, which is NOT in version
// control (see android/.gitignore and docs/RELEASE.md). Without it, release
// builds fall back to the debug key so CI and local smoke builds still produce
// an installable artifact — but such an artifact must never be uploaded to Play.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.track.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time; desugaring is required
        // even though minSdk is 26 (the plugin declares it as a hard requirement).
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        compose = true
    }

    defaultConfig {
        // Permanent Play Store application id. Mirrored by `_packageName` in
        // lib/main.dart (Play Billing queries + manage-subscription deep link);
        // the two must never drift apart.
        applicationId = "com.track.app"
        // 26, not flutter.minSdkVersion (21): Health Connect's client, the Compose
        // runtime Glance pulls in, and java.time all assume API 26+. A lower
        // minSdk compiles and then crashes on old devices.
        minSdk = 26
        targetSdk = 36
        // Read from pubspec.yaml `version: x.y.z+n` (n = versionCode).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Debug-signed "release" builds keep CI green and let a device
                // smoke-test run; Play upload requires the real keystore.
                signingConfigs.getByName("debug")
            }
            // The widget receiver, notification receivers and the focus service
            // are instantiated by the system, not referenced from kept code:
            // proguard-rules.pro is what stops R8 from silently removing them.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Kotlin 2.2 raises the old `android { kotlinOptions { jvmTarget } }` DSL to an
// error, so the JVM target is set through `compilerOptions` instead — the form
// Flutter's own app template ships. It must stay JVM_17: AGP 8.11 requires Java 17.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications requires desugar_jdk_libs >= 2.1.4.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ServiceCompat.startForeground (API 34 service-type call), NotificationCompat,
    // NotificationManagerCompat — used by the Focus Lock seam and MainActivity.
    implementation("androidx.core:core-ktx:1.15.0")

    // lifecycleScope for the widget refresh in MainActivity.
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")

    // Home-screen widget (Glance draws the rings).
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
    // TrackWidget state (PreferencesGlanceStateDefinition) uses these directly.
    implementation("androidx.datastore:datastore-preferences-core:1.1.1")

    // Wear OS data layer: pushes the widget snapshot to a paired watch
    // (android_overlay/wear/ documents the optional watch module).
    implementation("com.google.android.gms:play-services-wearable:18.2.0")
}
