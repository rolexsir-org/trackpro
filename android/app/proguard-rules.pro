# R8 keep rules for Track.
#
# Copy to android/app/proguard-rules.pro.
#
# Rationale: every entry below is a class the Android *system* instantiates from
# the manifest (receivers, services) or instantiates reflectively (Glance's widget
# factory). R8 has no static reference to them, so with `isMinifyEnabled = true`
# it removes them, the build succeeds, and the feature is simply missing at
# runtime — the worst possible failure shape because the APK looks fine.

# --- Glance home-screen widget -------------------------------------------------
-keep class androidx.glance.** { *; }
-keep class com.track.app.TrackWidget { *; }
-keep class com.track.app.TrackWidgetReceiver { *; }

# --- Scheduled notifications (flutter_local_notifications) ---------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# --- JSON: the widget snapshot is parsed by key name --------------------------
-keep class org.json.** { *; }

# --- Play Billing: the library is reflective in places ------------------------
-keep class com.android.billingclient.** { *; }

# --- Kotlin metadata / coroutines (GMS Data Layer, Wear) ----------------------
-keepclassmembers class kotlin.Metadata { public <methods>; }
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# ---------------------------------------------------------------------------
# Focus Lock (android_overlay/…/Focus*.kt)
# ---------------------------------------------------------------------------
# These three classes are named in AndroidManifest.xml and instantiated by the
# *system* (the service by ActivityManager, the panel activity by the detector), so
# R8 cannot see a reference to them from the code it keeps and would strip them. A
# stripped service fails at start-foreground time with a ClassNotFoundException that
# surfaces as "blocking silently did nothing" — the worst possible failure for this
# feature, because the app would have to have been honest about it.
-keep class com.track.app.FocusSessionService { *; }
-keep class com.track.app.FocusBlockOverlay { *; }
-keep class com.track.app.FocusStore { *; }
-keep class com.track.app.FocusChannel { *; }
-keep class com.track.app.ScreenTimeChannel { *; }

# The notification action and the service start are delivered as Intents whose
# target action strings are part of the contract with the manifest.
-keepclassmembers class com.track.app.FocusSessionService {
    public static <fields>;
    *** Companion;
}
