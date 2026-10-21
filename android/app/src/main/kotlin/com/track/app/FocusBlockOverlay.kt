package com.track.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.content.pm.PackageManager

/**
 * The panel the user sees when they open an app they asked to be covered.
 *
 * Rules this screen follows, all of them load-bearing:
 *
 *  1. **It is not a wall.** There are exactly two actions, both visible, both one tap
 *     (or one long press for "leave" in deep focus): leave the covered app, or end the
 *     session. Nothing is hidden, nothing is drawn over, no back-button interception.
 *  2. **It never imitates another app.** No fake keyboard, no imitation system dialog,
 *     no fake crash. It is a plain panel in Track Pro's own voice, and it says what it is.
 *  3. **No `FLAG_SECURE`.** An earlier generation of blocking apps set it so the panel
 *     could not be screenshotted or dismissed from Recents. Track Pro does not: the user
 *     must always be able to capture and share their own screen, and must always be
 *     able to leave. A block that cannot be photographed is a block that cannot be
 *     reported.
 *  4. **It can always be left.** The Home button works, the back button leaves, and
 *     "End session" stops everything immediately — including in deep focus, where
 *     ending is a deliberate press-and-hold rather than an impossible one.
 *  5. **It does not lie about the time.** The countdown is read from the same realtime
 *     clock the service uses (`SystemClock.elapsedRealtime`), not from a wall clock
 *     that the user or the network could move.
 */
class FocusBlockOverlay : Activity() {

    private var countdown: TextView? = null
    private var ticker: android.os.Handler? = null
    private var closing = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setFinishOnTouchOutside(false)
        // Deliberately NOT setShowWhenLocked(true) and NOT setTurnScreenOn(true): this
        // panel appears because the user opened an app, never over a locked screen.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window?.setBackgroundDrawable(ColorDrawable(Color.parseColor("#0B0B10")))
        }

        val label = FocusStore.label(this)
        val mode = FocusStore.mode(this)
        val accent = FocusStore.accent(this)
        val deep = mode == "deep"

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(64, 96, 64, 96)
            setBackgroundColor(Color.parseColor("#0B0B10"))
        }

        root.addView(TextView(this).apply {
            text = "This app is covered"
            setTextColor(Color.WHITE)
            textSize = 26f
        })

        root.addView(TextView(this).apply {
            text = "You asked Track Pro to cover this during a focus session."
            setTextColor(Color.parseColor("#9A9AA5"))
            textSize = 15f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 8)
        })

        val countdownView = TextView(this).apply {
            text = remainingLabel()
            setTextColor(Color.WHITE)
            textSize = 44f
            gravity = Gravity.CENTER
            setPadding(0, 40, 0, 8)
        }
        countdown = countdownView
        root.addView(countdownView)

        root.addView(TextView(this).apply {
            // The goal text is shown here (and only here) because the user is holding
            // the device and asked for the session; it is never put on the lock screen.
            text = "$label · ${remainingMinutes()} min left"
            setTextColor(Color.parseColor("#9A9AA5"))
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 40)
        })

        root.addView(Button(this).apply {
            text = "Leave this app"
            setOnClickListener { finish() }
        })

        val end = Button(this).apply {
            text = if (deep) "Hold to end session" else "End session"
            setTextColor(Color.WHITE)
            setOnClickListener {
                if (!deep) endSessionAndClose()
            }
            if (deep) {
                setOnLongClickListener {
                    endSessionAndClose()
                    true
                }
            }
        }
        root.addView(end, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = 16 })

        root.addView(TextView(this).apply {
            text = "Home and the emergency dialler always work. This panel can be closed at any time."
            setTextColor(Color.parseColor("#6E6E78"))
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 0)
        })

        setContentView(root)

        ticker = android.os.Handler(mainLooper).also { handler ->
            handler.post(object : Runnable {
                override fun run() {
                    countdown?.text = remainingLabel()
                    val left = FocusStore.endsRealtime(this@FocusBlockOverlay) - SystemClock.elapsedRealtime()
                    if (left <= 0) {
                        finish()
                        return
                    }
                    handler.postDelayed(this, 1_000)
                }
            })
        }
    }

    override fun onDestroy() {
        ticker?.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun endSessionAndClose() {
        if (closing) return
        closing = true
        // Tell the service to stop; the session row itself is closed by Dart on the next
        // foreground, so the outcome is decided in one place with the full record in hand.
        FocusSessionService.stop(this)
        finish()
    }

    private fun remainingMinutes(): Int {
        val left = FocusStore.endsRealtime(this) - SystemClock.elapsedRealtime()
        return ((left.coerceAtLeast(0L)) / 60_000L).toInt() + if (left % 60_000L > 0) 1 else 0
    }

    private fun remainingLabel(): String {
        val left = (FocusStore.endsRealtime(this) - SystemClock.elapsedRealtime()).coerceAtLeast(0L)
        val minutes = left / 60_000L
        val seconds = (left % 60_000L) / 1000L
        return "%02d:%02d".format(minutes, seconds)
    }

    companion object {
        private const val EXTRA_PACKAGE = "covered_package"

        /**
         * Whether this panel can legally be shown right now. Checked at both ends — here
         * and in the service — because the grant can be revoked between the two, and a
         * panel that appears when it should not is exactly the deceptive-overlay
         * behaviour this feature must never exhibit.
         */
        fun canShow(context: Context): Boolean =
            Settings.canDrawOverlays(context) && hasUsageAccess(context)

        /**
         * Usage access is checked here too: with the grant revoked the detector cannot
         * know that a covered app was opened, so a panel raised from stale state would
         * be describing a detection that did not happen.
         */
        private fun hasUsageAccess(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? android.app.AppOpsManager
                ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName,
                )
            }
            return mode == android.app.AppOpsManager.MODE_ALLOWED
        }

        fun intent(context: Context, coveredPackage: String): Intent =
            Intent(context, FocusBlockOverlay::class.java)
                .putExtra(EXTRA_PACKAGE, coveredPackage)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

        /**
         * The app's human name for a package, for logging/debug only. Guarded: a package
         * that has been uninstalled mid-session must not throw inside the detector.
         */
        fun appLabel(context: Context, coveredPackage: String): String = try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(coveredPackage, 0)).toString()
        } catch (t: PackageManager.NameNotFoundException) {
            coveredPackage
        }
    }
}
