import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // No `kotlin-android` here: with `android.builtInKotlin=false` (see
    // gradle.properties) the Flutter Gradle Plugin applies the Kotlin plugin
    // itself, and Flutter 3.47's template no longer applies it in the app
    // module. Applying it twice is what AGP 9 rejects.
    // Glance (the home-screen widget) compiles Compose down to RemoteViews; this
    // plugin is the only reason Compose appears in an otherwise all-Flutter app.
    // Its version must match the Kotlin version in settings.gradle.kts.
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
    compileSdk = flutter.compileSdkVersion // 36 on Flutter 3.47; tracks the SDK's verified value
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
        targetSdk = flutter.targetSdkVersion // 36 on Flutter 3.47; meets Play's 2026-08-31 API-36 floor
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
    // AndroidX ceiling (2026-10-20): the newest core-ktx (1.19.x) and lifecycle
    // (2.11.x) declare minCompileSdk 37 in their AAR metadata. API 37 requires
    // AGP 9.2+/Gradle 9.4+, which is outside Flutter 3.47's verified matrix
    // (AGP 9.1.0 / Gradle 9.3.1 / compileSdk 36), so those two are held at the
    // newest API-36-compatible releases (1.18.0 / 2.10.0). Glance 1.2.0 and
    // DataStore 1.2.1 were verified to carry no such floor. Revisit this cap
    // together with the next Flutter/AGP matrix bump — never independently.
    // flutter_local_notifications requires desugar_jdk_libs >= 2.1.4; 2.1.5 is the latest stable.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // ServiceCompat.startForeground (API 34 service-type call), NotificationCompat,
    // NotificationManagerCompat — used by the Focus Lock seam and MainActivity.
    implementation("androidx.core:core-ktx:1.18.0") // 1.19.x declares minCompileSdk 37; see the AndroidX ceiling note above

    // lifecycleScope for the widget refresh in MainActivity.
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0") // 2.11.x declares minCompileSdk 37; see the AndroidX ceiling note above

    // Home-screen widget (Glance draws the rings).
    implementation("androidx.glance:glance-appwidget:1.2.0")
    implementation("androidx.glance:glance-material3:1.2.0")
    // TrackWidget state (PreferencesGlanceStateDefinition) uses these directly.
    implementation("androidx.datastore:datastore-preferences-core:1.2.1")

    // Wear OS data layer: pushes the widget snapshot to a paired watch
    // (android_overlay/wear/ documents the optional watch module).
    implementation("com.google.android.gms:play-services-wearable:20.0.1")
}
