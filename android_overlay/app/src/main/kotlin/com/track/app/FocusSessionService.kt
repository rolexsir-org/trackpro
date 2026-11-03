package com.track.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat

/**
 * The detector.
 *
 * WHAT THIS IS: a foreground service that polls `UsageStatsManager.queryEvents` for
 * foreground-app transitions while a focus session runs, and raises the covering panel
 * when the app that just came to the front is one the user chose to cover.
 *
 * WHAT THIS IS NOT, and this matters more than what it is:
 *
 *  * It is not a filter. Track Pro cannot intercept a launch. It observes, and the panel
 *    appears a moment later. `queryEvents` is batched by the platform, so the honest
 *    description is "within a second or two, usually" — never "instantly", and never
 *    "the app cannot be opened".
 *  * It is not a VPN, an Accessibility Service, a Device Admin or a device owner.
 *    Those can cover a whole device and can also read and control everything on it;
 *    Track Pro deliberately holds none of them, and the manifest declares none of them.
 *  * It is not surveillance. Only the foreground package name and the timestamp are
 *    read, they are compared against the user's own list, and they are never written
 *    to disk or sent anywhere. The counters in [FocusStore] are integers.
 *
 * WHY A FOREGROUND SERVICE: Android kills ordinary background work, and a detector
 * that is dead while the app claims to be enforcing is exactly the failure this whole
 * feature is written to avoid. The service type is `specialUse` (see the manifest),
 * which is the honest classification: this is not media, not location, not a call —
 * it is a user-visible, user-started session timer, and the Play Console declaration
 * says so.
 *
 * WHY THE OVERLAY PERMISSION IS REQUIRED: two reasons, both real. (1) Drawing the
 * panel needs it. (2) Android's background-activity-launch rules only let an app
 * start an activity from the background when it holds SYSTEM_ALERT_WINDOW (or a
 * handful of other exemptions). Without the grant, the detector can still see the
 * app but must not pretend to be able to say anything about it — which is why the
 * Dart side reports `unavailable` rather than `armed` when the grant is missing.
 *
 * KILL PATHS THAT ARE HANDLED, AND HOW:
 *  * Permission revoked mid-session: the next channel state read reports the missing
 *    Usage Access/overlay grant. Dart records the live session as `lost`, so it is
 *    never shown as a clean completion.
 *  * Force-stop: the service dies, `serviceAlive()` goes false within
 *    [FocusStore.SERVICE_STALE_MS], and the session is reported as lost. Android
 *    gives a force-stopped app no callback at all — so the state is detected by the
 *    absence of a heartbeat, not invented.
 *  * Reboot: `elapsedRealtime` resets to zero. [FocusStore] stores both clocks, so
 *    Dart's `FocusEngine.recover` sees `nowRealtime < startedRealtime` and resolves
 *    the session as interrupted-by-restart instead of computing a nonsensical
 *    duration.
 *  * Process death of the app (not the service): the service keeps running and keeps
 *    its counters; the app rejoins by reading [FocusStore].
 *  * Battery restrictions: the OS may suspend the service. The heartbeat stops, the
 *    state reads as lost, and the app says the session ran without enforcement rather
 *    than claiming the blocks held.
 */
class FocusSessionService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var poller: Runnable? = null
    private var lastSeenPackage: String? = null
    private var overlayShownFor: String? = null
    private var stopped = false
    private var lastNotifiedMinute = -1

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        FocusStore.markServiceUp(this, true)
        startInForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSession()
            return START_NOT_STICKY
        }

        // `START_NOT_STICKY`: if Android kills this service, restarting it silently
        // would re-arm enforcement the user is not looking at, minutes after the
        // session's clock ran out. The session's real state is resolved by Dart on the
        // next foreground, where the user can see the answer.
        if (stopped) return START_NOT_STICKY
        schedule()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        poller?.let { handler.removeCallbacks(it) }
        FocusStore.markServiceUp(this, false)
        super.onDestroy()
    }

    private fun startInForeground() {
        val notification = buildNotification()
        try {
            FocusStore.attach(applicationContext)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // API 34+ requires the type to be declared at both the call site and
                // the manifest. Asking for it here and declaring it there is the only
                // combination that starts.
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            // A foreground start that fails (restricted by the OS, or the notification
            // permission refused on API 33+ where the FGS notification is still
            // required) must not take the app down. The Dart side reads the heartbeat
            // and will report the session as not enforced. Keep the throwable in logcat;
            // an unavailable service is a user-visible state, not an error to erase.
            Log.w(TAG, "could not enter the focus foreground service", t)
            FocusStore.markServiceUp(this, false)
            stopSelf()
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Focus session",
                // LOW: the ongoing notice is a statement of fact, not an alert. It must
                // never buzz — a session that interrupts to tell you it is protecting
                // you from interruption is a joke this app refuses to make.
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while a focus session is running, so you can always see and stop it."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, FocusSessionService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val remaining = (FocusStore.endsRealtime(this) - SystemClock.elapsedRealtime()).coerceAtLeast(0L)
        val minutes = (remaining / 60_000L) + if (remaining % 60_000L > 0) 1 else 0

        // Deliberately does NOT name the goal. The goal is the user's own text ("revision
        // for the exam"), and the lock screen is the one place it can leak. Same rule as
        // every other Track Pro notification.
        val text = if (FocusStore.blocking(this)) {
            "Covering ${FocusStore.blocked(this).size} app(s) · $minutes min left"
        } else {
            "Timer running · $minutes min left"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setContentTitle("Focus session running")
            .setContentText(text)
            .setContentIntent(open)
            .addAction(0, "End", stop)
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()
    }

    private fun schedule() {
        poller?.let { handler.removeCallbacks(it) }
        val runnable = object : Runnable {
            override fun run() {
                if (stopped) return
                tick()
                handler.postDelayed(this, POLL_MS)
            }
        }
        poller = runnable
        handler.post(runnable)
    }

    private fun tick() {
        if (FocusStore.sessionId(this) == null) {
            stopSession()
            return
        }
        if (SystemClock.elapsedRealtime() >= FocusStore.endsRealtime(this)) {
            // The session is over. Do NOT decide the outcome here: Dart owns that, and
            // a platform that quietly wrote "completed" would be claiming something it
            // cannot know (whether enforcement held for the whole session).
            stopSession()
            return
        }

        // The ongoing notice is the lock-screen clock. It used to be built once, at
        // start, and then read "25 min left" for the whole session; refresh it when
        // the whole-minute figure changes, which is cheap and keeps the one number a
        // user can see without opening the app honest.
        refreshNotification()

        val usage = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
        val now = SystemClock.elapsedRealtime()
        val windowStart = now - POLL_WINDOW_MS
        val events = usage.queryEvents(
            System.currentTimeMillis() - POLL_WINDOW_MS,
            System.currentTimeMillis(),
        )

        var latestPackage: String? = null
        var latestTime = 0L
        val event = UsageEvents.Event()
        var reported = false
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            reported = true
            val foregrounding =
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == LEGACY_MOVE_TO_FOREGROUND
            if (!foregrounding) continue
            if (event.timeStamp >= latestTime) {
                latestTime = event.timeStamp
                latestPackage = event.packageName
            }
        }

        // No events at all in the window is the signature of revoked usage access, of a
        // device that refuses to report, or of a genuinely idle phone. It is NOT counted
        // as evidence — the difference between "we saw nothing" and "we saw the app" is
        // the whole reason `detectionEvents` exists.
        if (!reported && latestPackage == null) {
            FocusStore.markServiceUp(this, true)
            return
        }

        val current = latestPackage
        if (current == null || current == lastSeenPackage) {
            FocusStore.markServiceUp(this, true)
            return
        }
        lastSeenPackage = current

        val covered = current != packageName && FocusStore.blocked(this).contains(current)
        FocusStore.bumpDetection(this, current, covered)
        if (!covered) return

        // The user opened an app they asked to be covered. Raise the panel — and only
        // if the grant that makes that possible is actually held. `canDrawOverlays`
        // false here means Android would silently drop the start; raising it anyway
        // would leave a counter that says "blocked" while nothing appeared.
        if (!FocusBlockOverlay.canShow(this)) return
        if (overlayShownFor == current && SystemClock.elapsedRealtime() - (lastOverlayAt) < OVERLAY_COOLDOWN_MS) {
            return
        }
        overlayShownFor = current
        lastOverlayAt = SystemClock.elapsedRealtime()
        try {
            startActivity(
                FocusBlockOverlay.intent(this, current).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            // This is deliberately after startActivity. A detected package is evidence
            // that the monitor works, but a refused background activity launch is not
            // evidence that Track Pro covered anything. Dart requires this count before
            // it may describe the session as verified.
            FocusStore.bumpOverlayShow(this)
        } catch (t: Throwable) {
            // Background activity starts can still be refused (OEM policies, an
            // in-call state, an app in picture-in-picture). The detection is already
            // counted; the panel just did not launch. Dart remains `armed`, not
            // `verified`, which is precisely the distinction this feature lives on.
            Log.w(TAG, "Android refused the focus coverage-panel launch", t)
        }
    }

    private var lastOverlayAt = 0L

    private fun refreshNotification() {
        val remaining = (FocusStore.endsRealtime(this) - SystemClock.elapsedRealtime()).coerceAtLeast(0L)
        val minutes = ((remaining + 59_999L) / 60_000L).toInt()
        if (minutes == lastNotifiedMinute) return
        lastNotifiedMinute = minutes
        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, buildNotification())
        } catch (t: Throwable) {
            // A notification that cannot be refreshed (permission refused, channel
            // blocked) must not stop the detector; the timer and the history are
            // unaffected. It is still retained in logcat for diagnosis.
            Log.w(TAG, "could not refresh the focus notification", t)
        }
    }

    private fun stopSession() {
        stopped = true
        poller?.let { handler.removeCallbacks(it) }
        poller = null
        FocusStore.markServiceUp(this, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    companion object {
        private const val TAG = "TrackFocusService"
        const val ACTION_START = "com.track.app.FOCUS_START"
        const val ACTION_STOP = "com.track.app.FOCUS_STOP"
        private const val CHANNEL_ID = "track.focus.running"
        private const val NOTIFICATION_ID = 4210

        /**
         * How often the detector looks. 1200 ms is a deliberate compromise: `queryEvents`
         * coalesces bursts, so polling faster mostly buys duplicate reads and battery
         * cost, while polling slower widens the window in which a covered app is briefly
         * usable. It is documented rather than tuned per device because tuning it per
         * device would be a claim about devices this code has not run on.
         */
        private const val POLL_MS = 1_200L

        /** The usage window each poll asks about, slightly wider than the poll gap. */
        private const val POLL_WINDOW_MS = 4_000L

        private const val OVERLAY_COOLDOWN_MS = 4_000L

        private const val LEGACY_MOVE_TO_FOREGROUND = 1

        fun start(context: Context) {
            val intent = Intent(context, FocusSessionService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FocusSessionService::class.java))
        }
    }
}
