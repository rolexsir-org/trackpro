# Wear OS module — how to add it

The phone app is the source of truth; the watch only mirrors it. This keeps a
single write path for the whole product (which is the entire point of a unified
tracker), and it means the tile is ~150 lines instead of another app's worth of
storage and sync logic.

## 1. Create the module

```bash
cd track_flutter
flutter create --platforms=android .            # host project (once)
mkdir -p wear/src/main/kotlin/com/track/app/wear
mkdir -p wear/src/main/res/values
# copy the two files from this folder:
#   src/main/kotlin/com/track/app/wear/TrackTileService.kt
#   src/main/AndroidManifest.xml
#   res/values/strings.xml
```

Then in `android/settings.gradle.kts`:

```kotlin
include(":wear")
project(":wear").projectDir = file("../wear")   // or keep it inside android/wear
```

## 2. `wear/build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21"
}

android {
    namespace = "com.track.app.wear"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.track.app"
        minSdk = 26          // Wear 3 / Tiles
        targetSdk = 36
        versionCode = 12
        versionName = "1.0.0"
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("androidx.glance:glance-wear-tiles:1.0.0-alpha07")
    implementation("androidx.compose.ui:ui-graphics:1.7.6")
    implementation("com.google.android.gms:play-services-wearable:18.2.0")  // Data Layer
    implementation("androidx.datastore:datastore-preferences:1.1.1")
}
```

Same `applicationId` as the phone app is what makes Play deliver them as one
install pair.

## 3. Phone side: push the snapshot

`android_overlay/app/src/main/kotlin/com/track/app/WearSync.kt` is copied into
the app module and called from the `track/widget` channel handler, so one Dart
write updates the home screen **and** the wrist:

```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "track/widget").setMethodCallHandler { call, result ->
    if (call.method == "refresh") {
        lifecycleScope.launch { TrackWidget.refresh(this@MainActivity) }
        WearSync.pushSnapshot(this@MainActivity, WidgetBridge.lastSnapshot)   // ← added
        result.success(null)
    } else result.notImplemented()
}
```

The snapshot JSON is the same ~600 bytes the widget uses — one serializer, three
surfaces (widget, watch, and the app itself).

## 4. What the tile shows

Three rings, a streak, and nothing else. It is a **glance**, not a control panel:
one tap opens the phone app. A `LOG_WATER` action callback is the obvious v2 (the
tile is already structured so that adding one `ActionCallback` is enough) — but
wrist logging needs offline queueing to be honest about it, so it is deliberately
not faked here.

## Status

Least-verified part of the repo: written against the alpha Wear Tiles API and
untested on hardware. Everything else (storage, health, notifications, haptics,
widget) is structured so this module can be added or dropped without touching a
single line of Dart.
