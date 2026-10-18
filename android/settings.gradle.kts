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
    // These three are one decision and must move together. The Flutter Gradle
    // Plugin *fails* the build (it does not warn) when any of them drops below
    // the floor its DependencyVersionChecker enforces:
    //     Gradle  >= 8.14.0   -> gradle/wrapper/gradle-wrapper.properties
    //     AGP     >= 8.11.1   -> this block
    //     KGP     >= 2.2.20   -> this block
    //
    // AGP 9 / Gradle 9 are deliberately NOT used. AGP 9 replaces the DSL (it is
    // what `android.newDsl` and `android.builtInKotlin` in Flutter's own template
    // opt out of) and needs Gradle 9.1+, which is above the ceiling Kotlin 2.2.20
    // supports. The triple below is the one combination that satisfies every
    // constraint at once: Flutter's floors, AGP 8.11's Gradle requirement (8.13+),
    // and Kotlin 2.2.20's ceilings (Gradle <= 8.14, AGP <= 8.11.1).
    // -------------------------------------------------------------------------
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // The Compose compiler is required by Glance (the home-screen widget); it is
    // the only reason Compose appears in an otherwise all-Flutter app. The version
    // MUST match the Kotlin version above.
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20" apply false
}

include(":app")
