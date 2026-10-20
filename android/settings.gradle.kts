pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // --- Android build-time version matrix -----------------------------------
    // These three are one decision and must move together. Selected 2026-10-20
    // from Flutter 3.47.7's own template / verified matrix
    // (packages/flutter_tools/lib/src/android/gradle_utils.dart in the Flutter
    // SDK): Gradle 9.3.1, AGP 9.1.0, KGP 2.4.0, JDK 17, compile/target SDK 36.
    //
    // Why not AGP 9.4 / Gradle 9.6 (newer in isolation)? Kotlin 2.4.x supports
    // AGP only up to 9.1, and Flutter 3.47's DependencyVersionChecker warns
    // above Gradle 9.3.1 / KGP 2.4.0 (its max known-and-supported set). The
    // triple below is the newest set that is mutually compatible *and*
    // Flutter-verified, which is the constraint that actually matters here.
    //
    // AGP 9 note: built-in Kotlin is NOT enabled for this project
    // (`android.builtInKotlin=false` in gradle.properties, the Flutter 3.47
    // template default). Enabling it requires every plugin in the tree to have
    // migrated off the Kotlin Gradle Plugin; that migration is upstream work,
    // and Flutter 3.44+ explicitly supports the legacy-KGP path used here.
    // -------------------------------------------------------------------------
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // The Compose compiler is required by Glance (the home-screen widget); it is
    // the only reason Compose appears in an otherwise all-Flutter app. The version
    // MUST match the Kotlin version above.
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.0" apply false
}

include(":app")
