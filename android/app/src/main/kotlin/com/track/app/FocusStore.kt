package com.track.app

import android.content.Context
import android.os.SystemClock

/**
 * The session the platform is currently enforcing, shared between the Dart side, the
 * foreground service and the process that comes back after a kill.
 *
 * Why SharedPreferences and not a ViewModel or an in-memory singleton: this state has
 * to survive **process death**, which is the normal case rather than the exception on
 * Android. If the session lived only in memory, a low-memory kill would erase the
 * fact that anything was ever running, and the app would have to guess when it
 * reopened. Instead the record is written before the service is started and cleared
 * only when the session genuinely ends — so what the user sees after a kill is what
 * was true, not what could be reconstructed.
 *
 * Nothing here is sensitive: a package list, a mode name, a goal label and clocks.
 * No usage history is ever written to disk — the detector reads usage events in
 * memory and keeps counters only.
 */
internal object FocusStore {

    private const val FILE = "track_focus_session"
    private const val KEY_ID = "session_id"
    private const val KEY_MODE = "mode"
    private const val KEY_LABEL = "label"
    private const val KEY_ACCENT = "accent"
    private const val KEY_STARTED_WALL = "started_wall_ms"
    private const val KEY_STARTED_REALTIME = "started_realtime_ms"
    private const val KEY_ENDS_REALTIME = "ends_realtime_ms"
    private const val KEY_PACKAGES = "packages"
    private const val KEY_BLOCK = "block"
    private const val KEY_DETECTIONS = "detection_events"
    private const val KEY_ATTEMPTS = "blocked_attempts"
    private const val KEY_OVERLAY_SHOWS = "overlay_shows"
    private const val KEY_SERVICE_UP = "service_up"
    private const val KEY_SERVICE_SEEN = "service_seen_realtime"
    private const val KEY_FOREGROUND = "foreground_package"

    private fun prefs(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun writeSession(
        context: Context,
        sessionId: String,
        mode: String,
        label: String,
        accent: Int,
        plannedMillis: Long,
        packages: List<String>,
        block: Boolean,
    ) {
        val nowRealtime = SystemClock.elapsedRealtime()
        prefs(context).edit()
            .putString(KEY_ID, sessionId)
            .putString(KEY_MODE, mode)
            .putString(KEY_LABEL, label)
            .putInt(KEY_ACCENT, accent)
            .putLong(KEY_STARTED_WALL, System.currentTimeMillis())
            .putLong(KEY_STARTED_REALTIME, nowRealtime)
            .putLong(KEY_ENDS_REALTIME, nowRealtime + plannedMillis)
            .putString(KEY_PACKAGES, packages.joinToString(","))
            .putBoolean(KEY_BLOCK, block)
            .putInt(KEY_DETECTIONS, 0)
            .putInt(KEY_ATTEMPTS, 0)
            .putInt(KEY_OVERLAY_SHOWS, 0)
            .putBoolean(KEY_SERVICE_UP, false)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    /**
     * The session id written for a running session, as read by the service. Kept as a
     * thin wrapper so the service never has to know the preference key names.
     */
    fun isLive(context: Context): Boolean = sessionId(context) != null

    fun sessionId(context: Context): String? = prefs(context).getString(KEY_ID, null)

    fun mode(context: Context): String = prefs(context).getString(KEY_MODE, "standard") ?: "standard"

    fun label(context: Context): String = prefs(context).getString(KEY_LABEL, "Focus session") ?: "Focus session"

    fun accent(context: Context): Int = prefs(context).getInt(KEY_ACCENT, 0xFF5B7CFA.toInt())

    fun startedWall(context: Context): Long = prefs(context).getLong(KEY_STARTED_WALL, 0L)

    fun startedRealtime(context: Context): Long = prefs(context).getLong(KEY_STARTED_REALTIME, 0L)

    fun endsRealtime(context: Context): Long = prefs(context).getLong(KEY_ENDS_REALTIME, 0L)

    fun blocked(context: Context): Set<String> =
        (prefs(context).getString(KEY_PACKAGES, "") ?: "")
            .split(",")
            .filter { it.isNotBlank() }
            .toSet()

    fun blocking(context: Context): Boolean = prefs(context).getBoolean(KEY_BLOCK, false)

    fun detectionEvents(context: Context): Int = prefs(context).getInt(KEY_DETECTIONS, 0)

    fun blockedAttempts(context: Context): Int = prefs(context).getInt(KEY_ATTEMPTS, 0)

    fun overlayShows(context: Context): Int = prefs(context).getInt(KEY_OVERLAY_SHOWS, 0)

    /** Called by the service once it is alive. */
    fun markServiceUp(context: Context, up: Boolean) {
        prefs(context).edit()
            .putBoolean(KEY_SERVICE_UP, up)
            .putLong(KEY_SERVICE_SEEN, SystemClock.elapsedRealtime())
            .apply()
    }

    /**
     * Whether the service is alive **now**. A stored `true` that has not been refreshed
     * for more than a few seconds is treated as dead: a service that was killed cannot
     * write its own obituary, and reporting a dead detector as alive would turn
     * "armed" into a lie.
     */
    fun serviceAlive(context: Context): Boolean {
        val p = prefs(context)
        if (!p.getBoolean(KEY_SERVICE_UP, false)) return false
        val seen = p.getLong(KEY_SERVICE_SEEN, 0L)
        return seen > 0 && SystemClock.elapsedRealtime() - seen < SERVICE_STALE_MS
    }

    /**
     * Records one observed foreground transition. `blockedNow` says whether the app
     * that came forward was on the user's list — the two counters are kept apart on
     * purpose, because "we saw the app" and "we did something about it" are different
     * facts and the UI is not allowed to blur them.
     */
    fun bumpDetection(context: Context, packageName: String, blockedNow: Boolean) {
        val p = prefs(context)
        p.edit()
            .putInt(KEY_DETECTIONS, p.getInt(KEY_DETECTIONS, 0) + 1)
            .putString(KEY_FOREGROUND, packageName)
            .putLong(KEY_SERVICE_SEEN, SystemClock.elapsedRealtime())
            .apply()
        if (blockedNow) bumpAttempt(context)
    }

    private var contextRef: Context? = null

    /** Called once at registration so the context-free readers below have an app context. */
    fun attach(context: Context) {
        contextRef = context.applicationContext
    }

    /**
     * The last package the detector saw come forward, or null when nothing is running.
     * Used for the session screen's diagnostics line and for the app's own logs — never
     * for a claim about what was or was not blocked.
     */
    fun foregroundPackageOrNull(): String? {
        val ctx = contextRef ?: return null
        if (sessionId(ctx) == null) return null
        return prefs(ctx).getString(KEY_FOREGROUND, null)
    }

    fun bumpAttempt(context: Context) {
        val p = prefs(context)
        p.edit().putInt(KEY_ATTEMPTS, p.getInt(KEY_ATTEMPTS, 0) + 1).apply()
    }

    /**
     * Records a coverage-panel launch that Android accepted. This is intentionally
     * separate from [bumpDetection]: a detected foreground app with a refused
     * background activity launch must never become evidence that it was covered.
     */
    fun bumpOverlayShow(context: Context) {
      val p = prefs(context)
      p.edit().putInt(KEY_OVERLAY_SHOWS, p.getInt(KEY_OVERLAY_SHOWS, 0) + 1).apply()
    }

    /** How long the service may go without a heartbeat before it is called dead. */
    private const val SERVICE_STALE_MS = 12_000L
}
