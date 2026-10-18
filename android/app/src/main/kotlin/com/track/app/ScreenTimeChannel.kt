package com.track.app

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.TimeZone

/**
 * `track/screen_time` — the Screen time tracker's link to Android's own usage
 * totals (`UsageStatsManager`), behind the user-granted "Usage access" app-op.
 *
 * The same contract as [FocusChannel]: **absence is never success.** Every call
 * either reports a fact the platform produced, or reports nothing. No grant →
 * empty totals and `usageAccess: false`, never a fabricated number. The Dart
 * layer (`ScreenTimeService`) is written to treat that as "manual logging still
 * works", not as zero screen time.
 *
 * WHAT IS READ: `TOTAL_TIME_FOREGROUND` per package per day — how long each app
 * was in the foreground. That is screen *time*, not content: no notifications,
 * no text, no URLs, no usage *events* leave this class. Nothing is written to
 * disk here; the totals travel to Dart once, where the user's own tracker rows
 * are written with `source: "usage"` so a manual entry always wins.
 *
 * KNOWN LIMITATIONS, stated rather than hidden:
 *  * `INTERVAL_DAILY` buckets are aligned to local midnight on stock Android,
 *    but some OEM builds return buckets with odd edges. Each bucket is
 *    attributed to the local calendar day of its `firstTimeStamp`, and a day's
 *    total is clamped to 1440 minutes — the same bound `ValueValidation`
 *    enforces on the Dart side — so a misaligned bucket can never invent a
 *    26-hour day.
 *  * Usage Access can be revoked at any moment; the next call simply reports
 *    `usageAccess: false` and empty data. The Dart side re-probes on every
 *    resume and says so on screen.
 *  * On a handful of Android 14 builds `queryUsageStats` returns empty lists
 *    even with the grant. That is reported as empty data plus
 *    `usageAccess: true` — the UI offers "sync now" and an honest empty state
 *    rather than claiming the user did not use their phone.
 */
internal object ScreenTimeChannel {

    const val CHANNEL = "track/screen_time"
    private const val TAG = "TrackScreenTime"

    private lateinit var appContext: Context

    fun register(engineMessenger: BinaryMessenger, context: Context) {
        appContext = context.applicationContext
        MethodChannel(engineMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Thread {
                val answer: Any? = try {
                    handle(call)
                } catch (t: Throwable) {
                    // A platform exception must never cross the channel as a crash.
                    Log.w(TAG, "screen time channel ${call.method} failed", t)
                    null
                }
                main.post { result.success(answer) }
            }.start()
        }
    }

    /** Main-thread trampoline for results produced off the UI thread. */
    private val main = Handler(Looper.getMainLooper())

    private fun handle(call: MethodCall): Any? = when (call.method) {
        "probe" -> mapOf(
            "android" to true,
            "screenTimeChannel" to true,
            "sdk" to Build.VERSION.SDK_INT,
        )

        "permission" -> mapOf("usageAccess" to hasUsageAccess())

        "openUsageAccess" -> launch(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))

        "dailyMinutes" -> dailyMinutes(call.argument<Int>("days") ?: 7)

        "todayByApp" -> todayByApp(call.argument<Int>("limit") ?: 6)

        else -> null
    }

    // ------------------------------------------------------------------ data
    /**
     * Screen minutes per local day for the last `days` days (including today),
     * as `[{"day": yyyymmdd, "minutes": double}, …]`, oldest first.
     */
    private fun dailyMinutes(days: Int): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()
        val bounded = days.coerceIn(1, 90)
        val now = System.currentTimeMillis()
        val start = startOfLocalDay(now) - (bounded - 1L) * DAY_MS

        val totals = HashMap<Long, Double>() // dayKey yyyymmdd -> minutes
        for (stat in query(start, now)) {
            val foregroundMs = stat.totalTimeInForeground
            if (foregroundMs <= 0L) continue
            val day = dayKeyOf(stat.firstTimeStamp.takeIf { it > 0L } ?: stat.lastTimeUsed)
            if (day < dayKeyOf(start) || day > dayKeyOf(now)) continue
            totals[day] = (totals[day] ?: 0.0) + foregroundMs / 60_000.0
        }

        // Clamp to 24 h and drop anything unstorable: a chart is only as
        // trustworthy as its worst point, and an OEM bucket quirk must not draw
        // a 26-hour bar.
        return totals.entries
            .sortedBy { it.key }
            .mapNotNull { (day, minutes) ->
                val clamped = minutes.coerceIn(0.0, 1440.0)
                if (clamped <= 0.0) null
                else mapOf("day" to day, "minutes" to (Math.round(clamped * 10.0) / 10.0))
            }
    }

    /**
     * Today's foreground minutes per app, most-used first, as
     * `[{"package": …, "label": …, "minutes": …}, …]`.
     */
    private fun todayByApp(limit: Int): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()
        val now = System.currentTimeMillis()
        val start = startOfLocalDay(now)
        val totals = HashMap<String, Double>()
        for (stat in query(start, now)) {
            val foregroundMs = stat.totalTimeInForeground
            if (foregroundMs <= 0L) continue
            val pkg = stat.packageName ?: continue
            if (pkg == appContext.packageName) continue
            totals[pkg] = (totals[pkg] ?: 0.0) + foregroundMs / 60_000.0
        }

        val top = totals.entries
            .sortedByDescending { it.value }
            .take(limit.coerceIn(0, 25))

        return top.map { (pkg, minutes) ->
            mapOf(
                "package" to pkg,
                "label" to labelOf(pkg),
                "minutes" to (Math.round(minutes.coerceIn(0.0, 1440.0) * 10.0) / 10.0),
            )
        }
    }

    private fun query(startMs: Long, endMs: Long): List<UsageStats> {
        val manager = appContext.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()
        return try {
            manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startMs, endMs)
                ?.filter { it.totalTimeInForeground > 0L }
                ?: emptyList()
        } catch (t: Throwable) {
            Log.w(TAG, "queryUsageStats failed", t)
            emptyList()
        }
    }

    private fun labelOf(packageName: String): String = try {
        val pm = appContext.packageManager
        val info = pm.getApplicationInfo(packageName, 0)
        pm.getApplicationLabel(info).toString().ifBlank { packageName }
    } catch (t: Throwable) {
        packageName
    }

    // ------------------------------------------------------------------ time
    private const val DAY_MS = 24L * 60L * 60L * 1000L

    /** Start of the local calendar day containing [epochMs]. */
    private fun startOfLocalDay(epochMs: Long): Long {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.timeInMillis = epochMs
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    /** `yyyymmdd` (local) for a timestamp — the same key shape Dart's `dayKey` writes. */
    private fun dayKeyOf(epochMs: Long): Long {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.timeInMillis = epochMs
        return cal.get(Calendar.YEAR) * 10_000L +
            (cal.get(Calendar.MONTH) + 1) * 100L +
            cal.get(Calendar.DAY_OF_MONTH)
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

    private fun launch(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
        true
    } catch (t: Throwable) {
        Log.w(TAG, "could not open $intent", t)
        false
    }
}
