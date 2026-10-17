package com.track.app.wear

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.Canvas
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.wear.tiles.GlanceTileService
import androidx.glance.wear.tiles.provideContent
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject

/**
 * Wear tile: the same three rings as the phone widget, on the wrist.
 *
 * Data path — the phone is the source of truth, the watch only mirrors it:
 *
 *   Drift write → AppState → WidgetBridge (Dart) → snapshot JSON
 *   → phone pushes it over the Wearable Data Layer (`/track/snapshot`)
 *   → TrackSnapshotListenerService (below) stores it in DataStore
 *   → the tile renders on the next request.
 *
 * The watch never opens SQLite and never writes history — logging from the
 * wrist is deliberately *not* in this tile. One tap opens the phone app, which
 * keeps a single write path (and a single source of truth) for the whole
 * product. Add a `LOG_WATER` ActionCallback later if you want wrist logging;
 * the tile is already structured for it.
 *
 * Requires: `androidx.glance:glance-wear-tiles:1.0.0-alpha07` and
 * `com.google.android.gms:play-services-wearable:18.2.0` (see build.gradle note).
 * This file is the least-verified part of the repo: it compiles against the
 * alpha Wear Tiles API and should be smoke-tested on a paired watch before ship.
 */
class TrackTileService : GlanceTileService() {

    override suspend fun tileRequest(
        context: Context,
        glanceId: GlanceId,
    ) {
        val snapshot = TrackSnapshotStore.read(context)
        provideContent {
            TileContent(snapshot)
        }
    }

    @Composable
    private fun TileContent(payload: JSONObject?) {
        val rings = payload?.optJSONArray("rings")
        val streak = payload?.optInt("streak", 0) ?: 0

        Box(modifier = GlanceModifier.fillMaxSize().background(Color(0xFF000000)).padding(10.dp)) {
            Column(modifier = GlanceModifier.fillMaxSize()) {
                Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(text = "Track Pro", style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.White)))
                    Spacer(GlanceModifier.defaultWeight())
                    if (streak > 0) {
                        Text(
                            text = "🔥$streak",
                            style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium, color = ColorProvider(Color.White)),
                        )
                    }
                }

                Spacer(GlanceModifier.height(8.dp))

                Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    if (rings == null || rings.length() == 0) {
                        Text(
                            text = "Open Track Pro on your phone",
                            style = TextStyle(fontSize = 11.sp, color = ColorProvider(Color.White)),
                        )
                    } else {
                        for (i in 0 until rings.length()) {
                            val ring = rings.getJSONObject(i)
                            Ring(
                                pct = ring.optDouble("pct", 0.0).toFloat(),
                                value = ring.optString("value"),
                                color = Color(ring.optInt("color")),
                                color2 = Color(ring.optInt("color2")),
                            )
                            if (i < rings.length() - 1) Spacer(GlanceModifier.width(10.dp))
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun Ring(pct: Float, value: String, color: Color, color2: Color) {
        val clamped = pct.coerceIn(0f, 1f)
        Box(modifier = GlanceModifier.size(52.dp), contentAlignment = Alignment.Center) {
            Canvas(modifier = GlanceModifier.size(52.dp)) {
                val stroke = 6f
                val arcSize = Size(size.width - stroke, size.height - stroke)
                val topLeft = Offset(stroke / 2f, stroke / 2f)
                drawArc(
                    color = Color(0x33FFFFFF),
                    startAngle = 0f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = stroke),
                )
                if (clamped > 0f) {
                    drawArc(
                        brush = Brush.linearGradient(listOf(color, color2), Offset.Zero, Offset(size.width, size.height)),
                        startAngle = -90f,
                        sweepAngle = 360f * clamped,
                        useCenter = false,
                        topLeft = topLeft,
                        size = arcSize,
                        style = Stroke(width = stroke, cap = StrokeCap.Round),
                    )
                }
            }
            Text(
                text = value,
                style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.White)),
            )
        }
    }
}

/// Receives `/track/snapshot` from the phone and stashes it for the tile.
class TrackSnapshotListenerService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        events.forEach { event ->
            if (event.type != DataEvent.TYPE_CHANGED) return@forEach
            val item = event.dataItem
            if (item.uri.path != TrackSnapshotStore.PATH) return@forEach
            val json = DataMapItem.fromDataItem(item).dataMap.getString(TrackSnapshotStore.KEY) ?: return@forEach
            TrackSnapshotStore.write(this, json)
        }
    }
}

/// Tiny persistence shim so the tile, the listener and the phone agreement all
/// read the same key.
object TrackSnapshotStore {
    const val PATH = "/track/snapshot"
    const val KEY = "snapshot_json"
    private const val PREFS = "track_wear"
    private const val PREFS_KEY = "snapshot"

    fun read(context: Context): JSONObject? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(PREFS_KEY, null)
            ?.let { runCatching { JSONObject(it) }.getOrNull() }

    fun write(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(PREFS_KEY, json).apply()
    }
}
