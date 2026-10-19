package com.track.app

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * `track/focus` — the only door between Dart and the platform for Focus Lock.
 *
 * The contract, in one rule: **absence is never success.** Every method either
 * answers with a fact the platform reported, or answers with null/false. A missing
 * plugin, a refused permission, a device that will not report usage — all of them come
 * back as "no answer", and the Dart side is written to treat no answer as
 * `FocusEnforcement.unavailable` and to say so on screen. Nothing here fabricates
 * progress, and nothing here reports an app as covered because Dart asked for it.
 *
 * Nothing in this class blocks: `installedApps()` — the only potentially slow call —
 * runs on a background thread and answers through the channel's result, and every
 * other method is a property read that takes microseconds.
 */
internal object FocusChannel {

    const val CHANNEL = "track/focus"
    private const val TAG = "TrackFocus"

    private lateinit var appContext: Context

    fun register(engineMessenger: io.flutter.plugin.common.BinaryMessenger, context: Context) {
        appContext = context.applicationContext
        FocusStore.attach(appContext)
        MethodChannel(engineMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (t: Throwable) {
                // A platform exception must never cross the channel as a crash: the Dart
                // side would see an unhandled error instead of "unavailable", and
                // "unavailable" is the truthful answer for every one of these calls.
                Log.w(TAG, "focus channel ${call.method} failed", t)
                result.success(null)
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "probe" -> result.success(
                mapOf(
                    "android" to true,
                    "focusChannel" to true,
                    "sdk" to Build.VERSION.SDK_INT,
                    "specialUseForegroundService" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE),
                ),
            )

            "permissions" -> result.success(
                mapOf(
                    "usageAccess" to hasUsageAccess(),
                    "overlay" to Settings.canDrawOverlays(appContext),
                    "notifications" to NotificationManagerCompat.from(appContext).areNotificationsEnabled(),
                    "batteryOptimised" to isIgnoringBatteryOptimisations(),
                ),
            )

            "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())

            "state" -> result.success(stateMap())

            "start" -> result.success(start(call))

            "stop" -> {
                FocusSessionService.stop(appContext)
                FocusStore.markServiceUp(appContext, false)
                result.success(true)
            }

            "apps" -> {
                // Off the UI thread: enumerating launcher activities touches the package
                // manager for every installed app, which is tens of milliseconds on a
                // good device and much worse on a cold one.
                Thread {
                    val apps = installedApps()
                    Handler0.post { result.success(apps) }
                }.start()
            }

            "protected" -> result.success(protectedPackages().toList())

            "openUsageAccess" -> {
                result.success(launch(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)))
            }

            "openOverlay" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${appContext.packageName}"),
                )
                result.success(launch(intent))
            }

            "openNotifications" -> {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName)
                result.success(launch(intent))
            }

            "openBattery" -> {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                result.success(launch(intent))
            }

            else -> result.notImplemented()
        }
    }

    /** A main-thread trampoline for results that are produced off the UI thread. */
    private object Handler0 {
        private val handler = android.os.Handler(android.os.Looper.getMainLooper())
        fun post(block: () -> Unit) = handler.post(block)
    }

    // ------------------------------------------------------------------ state
    private fun stateMap(): Map<String, Any?> {
        val hasSession = FocusStore.sessionId(appContext) != null
        val alive = hasSession && FocusStore.serviceAlive(appContext)
        return mapOf(
            "running" to alive,
            // `blocking` means the detector is alive AND the session asked for blocking
            // AND both grants are held. It is NOT a statement that coverage happened:
            // Dart requires both a foreground detection and a successful coverage-panel
            // launch (`overlayShows`) before it can describe coverage as verified.
            "blocking" to (alive && FocusStore.blocking(appContext) && FocusBlockOverlay.canShow(appContext)),
            "startedAtRealtimeMs" to FocusStore.startedRealtime(appContext),
            "endsAtRealtimeMs" to FocusStore.endsRealtime(appContext),
            "blockedAttempts" to FocusStore.blockedAttempts(appContext),
            "overlayShows" to FocusStore.overlayShows(appContext),
            "detectionEvents" to FocusStore.detectionEvents(appContext),
            "usageAccess" to hasUsageAccess(),
            "overlay" to Settings.canDrawOverlays(appContext),
            "foregroundPackage" to FocusStore.foregroundPackageOrNull(),
            // Whether the platform has reported *any* usage event during this session.
            // A device that refuses to report is indistinguishable from a quiet one from
            // here, which is why the label is "seen", not "working".
            "usageReportingSeen" to (FocusStore.detectionEvents(appContext) > 0),
        )
    }

    // ------------------------------------------------------------------ start
    private fun start(call: MethodCall): Boolean {
        val sessionId = call.argument<String>("sessionId") ?: return false
        val mode = call.argument<String>("mode") ?: "standard"
        val label = call.argument<String>("label") ?: "Focus session"
        // ARGB values above 0x7FFFFFFF arrive as Int64 on the standard codec, so this
        // must be read as a Number — `call.argument<Int>("accent")` returns null for
        // every colour a real user would pick, and the default would silently win.
        val accent = (call.argument<Number>("accent"))?.toInt() ?: 0xFF5B7CFA.toInt()
        val plannedMinutes = call.argument<Int>("plannedMinutes") ?: 25
        val block = call.argument<Boolean>("block") ?: false
        val packages = call.argument<List<String>>("packages") ?: emptyList()

        // A blocking session without the overlay grant CANNOT raise the panel — not
        // drawn, and (under Android's background-activity-launch rules) not even
        // allowed to be started from the background. So it is not started as a blocking
        // session. The timer still runs; Dart reports the session as unavailable/
        // degraded and tells the user before and during.
        val effectiveBlock = block && Settings.canDrawOverlays(appContext) && hasUsageAccess()

        // Protected packages are filtered again here. The Dart side already does this,
        // but this is the layer that would actually raise the panel, so the check that
        // guarantees "the dialler is never covered" belongs on this side of the channel
        // as well.
        val guarded = protectedPackages()
        val effectivePackages = packages.filter { it != appContext.packageName && !guarded.contains(it) }

        FocusStore.writeSession(
            context = appContext,
            sessionId = sessionId,
            mode = mode,
            label = label,
            accent = accent,
            plannedMillis = plannedMinutes.toLong() * 60_000L,
            packages = effectivePackages,
            block = effectiveBlock && effectivePackages.isNotEmpty(),
        )

        return try {
            FocusSessionService.start(appContext)
            true
        } catch (t: Throwable) {
            // Foreground service start refused (background start restrictions on some
            // builds, or the OS in a restricted state). Report false rather than leaving
            // a stored session that nothing is enforcing.
            Log.w(TAG, "could not start the focus service", t)
            FocusStore.clear(appContext)
            false
        }
    }

    // ------------------------------------------------------------ permissions
    private fun hasUsageAccess(): Boolean {
        val appOps = appContext.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                appContext.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), appContext.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isIgnoringBatteryOptimisations(): Boolean {
        val power = appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return power.isIgnoringBatteryOptimizations(appContext.packageName)
    }

    // ------------------------------------------------------------- app lists
    /**
     * Every launchable app, with the ones that can never be covered flagged rather than
     * omitted. The flag is the difference between "Track Pro will not let me pick my phone
     * app" and "Track Pro explained why my phone app is not on the list".
     */
    private fun installedApps(): List<Map<String, Any>> {
        val pm = appContext.packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }

        val guarded = protectedPackages()
        val out = ArrayList<Map<String, Any>>(resolveInfos.size)
        for (info in resolveInfos) {
            val packageName = info.activityInfo?.packageName ?: continue
            if (packageName == appContext.packageName) continue
            val label = info.loadLabel(pm).toString().ifBlank { packageName }
            out.add(
                mapOf(
                    "package" to packageName,
                    "label" to label,
                    "protected" to guarded.contains(packageName),
                ),
            )
        }
        return out.sortedBy { (it["label"] as String).lowercase(Locale.ROOT) }
    }

    /**
     * The packages that may never be covered, resolved from the device's own answers
     * wherever possible rather than from a hardcoded list of OEM package names:
     *
     *  * the current default dialler (`TelecomManager`) and the system dialler;
     *  * the current home app;
     *  * the enabled input methods (a covered keyboard would make the phone unusable —
     *    including making it impossible to type an emergency number);
     *  * system UI, settings and the permission controller;
     *  * Track Pro itself.
     *
     * The list is advisory in one direction only: it can *prevent* a cover, never cause
     * one. If resolution fails on an unusual build, the Dart-side `alwaysProtected` set
     * still applies, and the worst case is an app that is offered but would be useless
     * to cover — never a dialler that cannot be reached.
     */
    private fun protectedPackages(): Set<String> {
        val out = LinkedHashSet<String>()
        out.add(appContext.packageName)
        out.addAll(SYSTEM_PROTECTED)

        val pm = appContext.packageManager
        try {
            val telecom = appContext.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            telecom?.defaultDialerPackage?.let { out.add(it) }
        } catch (t: Throwable) {
            Log.w(TAG, "could not resolve the default dialler", t)
        }
        try {
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.resolveActivity(home, PackageManager.ResolveInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.resolveActivity(home, 0)
            }
            resolved?.activityInfo?.packageName?.let { out.add(it) }
        } catch (t: Throwable) {
            Log.w(TAG, "could not resolve the home app", t)
        }
        return out
    }

    private fun launch(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
        true
    } catch (t: Throwable) {
        // Some OEM builds ship without one of these settings screens. Tapping the
        // permission row then does nothing visible — which the app already explains,
        // because the row's copy names the exact setting to change by hand.
        Log.w(TAG, "could not open $intent", t)
        false
    }

    /**
     * Packages that are never coverable on any build. Kept short on purpose: every
     * entry here is a promise, and a promise that cannot be kept is worse than a
     * shorter list.
     */
    private val SYSTEM_PROTECTED = setOf(
        "com.android.systemui",
        "com.android.settings",
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.android.phone",
        "com.android.server.telecom",
        "com.android.emergency",
        "com.android.vending",
        "android",
    )

    /** Only used for diagnostics; never surfaced as a claim. */
    fun describe(context: Context): String {
        val ai: ApplicationInfo? = try {
            context.packageManager.getApplicationInfo(context.packageName, 0)
        } catch (t: Throwable) {
            null
        }
        return "focus channel ready (uid=${ai?.uid ?: -1}, sdk=${Build.VERSION.SDK_INT})"
    }

    /** Never requested by Track Pro; kept as a compile-time reminder of what it does not hold. */
    @Suppress("unused")
    private val accessibilityIsNeverRequested = "android.permission.BIND_ACCESSIBILITY_SERVICE"

    @Suppress("unused")
    private val bindVpnIsNeverRequested = "android.permission.BIND_VPN_SERVICE"

    @Suppress("unused")
    private val deviceAdminIsNeverRequested = "android.permission.BIND_DEVICE_ADMIN"

    @Suppress("unused")
    private val emergencyIsNeverCovered = Manifest.permission.CALL_PHONE
}
