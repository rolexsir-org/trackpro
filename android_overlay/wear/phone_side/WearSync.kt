package com.track.app

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

/**
 * Pushes the widget snapshot to a paired Wear OS device over the Data Layer.
 *
 * Called from the `track/widget` channel handler, so a single Dart write fans out
 * to the home-screen widget *and* the wrist. The snapshot is the same ~600-byte
 * JSON in both cases: one serializer, two renderers.
 *
 * Failure is always silent — most users have no watch, and "no watch" must never
 * be an error path in a daily tracker.
 */
object WearSync {

    private const val TAG = "WearSync"
    const val PATH = "/track/snapshot"
    const val KEY = "snapshot_json"

    /** Flutter's shared_preferences file + key (we read it instead of holding state). */
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val FLUTTER_KEY = "flutter.track.widget.snapshot"

    private var lastPush = 0L

    fun pushSnapshot(context: Context, snapshotIn: String? = null) {
        val json = snapshotIn ?: readSnapshot(context) ?: return
        // Rate-limit: a burst of water logs should not spam the Data Layer.
        val now = System.currentTimeMillis()
        if (now - lastPush < 1500) return
        lastPush = now

        if (!hasPairedNode(context)) return

        try {
            val request = PutDataMapRequest.create(PATH).apply {
                dataMap.putString(KEY, json)
                dataMap.putLong("sent_at", now)
            }.asPutDataRequest().setUrgent()

            Wearable.getDataClient(context)
                .putDataItem(request)
                .addOnFailureListener { e -> Log.d(TAG, "wear push failed: ${e.message}") }
        } catch (e: Exception) {
            Log.d(TAG, "wear push unavailable: ${e.message}")
        }
    }

    /** No watch paired → skip the work entirely, which is the common case. */
    private fun hasPairedNode(context: Context): Boolean = try {
        val nodes = Wearable.getNodeClient(context).connectedNodes
        // The blocking await is fine here: this runs off the UI thread and the
        // result is cached by the Data Layer.
        return com.google.android.gms.tasks.Tasks.await(nodes, 2, java.util.concurrent.TimeUnit.SECONDS)
            .any { it.isNearby }
    } catch (e: Exception) {
        false
    }

    private fun readSnapshot(context: Context): String? =
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).getString(FLUTTER_KEY, null)
}
