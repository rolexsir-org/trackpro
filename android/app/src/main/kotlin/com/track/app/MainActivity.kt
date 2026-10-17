package com.track.app

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * Hosts the two tiny native seams Track Pro needs:
 *
 *  1. `track/haptics` — the app's haptic vocabulary mapped onto Android's system
 *     constants. On API 30+ that means CONFIRM / REJECT / GESTURE_END, which are
 *     tuned per device/OEM and — crucially — respect the user's own "touch
 *     feedback" setting and intensity. A raw `Vibrator` call ignores both, which
 *     is why so many "iOS-feel" ports buzz like a pager.
 *  2. `track/widget` — nudges the Glance home-screen widget to redraw after Dart
 *     has written a fresh snapshot.
 *  3. `track/focus` — Focus Lock's enforcement seam: permission state, the monotonic
 *     clock, the installed-app list, and start/stop for the session service. It lives
 *     in [FocusChannel] because it is the one seam with real state behind it; see that
 *     file for the contract, which is "absence is never success".
 *
 * Both are fire-and-forget: a missing haptic must never cost a frame.
 *
 * `FlutterFragmentActivity` rather than `FlutterActivity`: the Health Connect
 * permission flow and Play Billing both use the AndroidX ActivityResult APIs,
 * which need a fragment host. Switching to plain `FlutterActivity` compiles and
 * then fails at the permission sheet, which is a miserable bug to chase on a
 * device.
 */
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "track/haptics").setMethodCallHandler { call, result ->
            when (call.method) {
                "selection" -> perform(HapticFeedbackConstants.KEYBOARD_TAP, HapticFeedbackConstants.CLOCK_TICK)
                "light" -> perform(HapticFeedbackConstants.VIRTUAL_KEY, HapticFeedbackConstants.CLOCK_TICK)
                "hold" -> perform(HapticFeedbackConstants.LONG_PRESS, HapticFeedbackConstants.KEYBOARD_TAP)
                "commit" -> perform(HapticFeedbackConstants.CONFIRM, HapticFeedbackConstants.VIRTUAL_KEY)
                "warning" -> perform(HapticFeedbackConstants.REJECT, HapticFeedbackConstants.LONG_PRESS)
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            result.success(null)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "track/widget").setMethodCallHandler { call, result ->
            if (call.method == "refresh") {
                lifecycleScope.launch { TrackWidget.refresh(this@MainActivity) }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        FocusChannel.register(flutterEngine.dartExecutor.binaryMessenger, this)
    }

    /**
     * Tries the modern constant first, then falls back to one that exists on the
     * current API level, so this works from API 21 to 36 without a version table
     * in Dart.
     */
    private fun perform(modern: Int, legacy: Int) {
        val view: View = window?.decorView ?: return
        val constant = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) modern else legacy
        // FLAG_IGNORE_VIEW_SETTING only skips the *view's* own flag. The global
        // setting is deliberately NOT ignored: a user who turned touch feedback
        // off in system settings must not be buzzed anyway, which is what the
        // previous FLAG_IGNORE_GLOBAL_SETTING did.
        view.performHapticFeedback(constant, HapticFeedbackConstants.FLAG_IGNORE_VIEW_SETTING)
    }
}
