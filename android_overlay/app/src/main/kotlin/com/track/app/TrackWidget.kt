package com.track.app

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.Canvas
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.updateAll
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
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import org.json.JSONObject

/**
 * Home-screen widget: today's three leading rings, the streak, and one line
 * about what is still open.
 *
 * Data flow (one direction, one source of truth):
 *
 *   Drift write → AppState → WidgetBridge (Dart) → JSON in
 *   `FlutterSharedPreferences` under `flutter.track.widget.snapshot`
 *   → this widget renders it → `TrackWidget.refresh()` redraws.
 *
 * It never touches SQLite. A widget drawing three arcs does not deserve its own
 * database connection, migration path and memory budget — and the snapshot is
 * ~600 bytes instead of a 40 MB plugin boot.
 *
 * Every tap opens MainActivity: the widget is a *door* into the app, which is
 * the whole point of shipping one.
 */
class TrackWidget : GlanceAppWidget() {

    override val sizeMode: SizeMode = SizeMode.Responsive(
        setOf(DpSize(160.dp, 110.dp), DpSize(250.dp, 110.dp), DpSize(250.dp, 220.dp))
    )

    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Read once from Flutter's prefs, then keep it in the widget's own state
        // so system-triggered re-renders (resize, theme change) are free.
        val snapshot = readSnapshot(context)
        updateAppWidgetState(context, id) { prefs ->
            val next = prefs.toMutablePreferences()
            next[SNAPSHOT_KEY] = snapshot.orEmpty()
            next
        }

        provideContent {
            val state = currentState<Preferences>()
            val payload = state[SNAPSHOT_KEY]?.takeIf { it.isNotBlank() }?.let { runCatching { JSONObject(it) }.getOrNull() }
            WidgetContent(payload, context)
        }
    }

    @Composable
    private fun WidgetContent(payload: JSONObject?, context: Context) {
        val rings = payload?.optJSONArray("rings")
        val streak = payload?.optInt("streak", 0) ?: 0
        val summary = payload?.optString("summary").orEmpty()

        GlanceTheme {
            Column(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .appWidgetBackground()
                    .background(Color(0xFFF2F2F7))
                    .cornerRadius(24.dp)
                    .padding(16.dp)
                    .clickable(actionStartActivity(Intent(context, MainActivity::class.java))),
            ) {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(text = "Track Pro", style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Bold))
                    Spacer(GlanceModifier.defaultWeight())
                    if (streak > 0) {
                        Text(
                            text = "🔥 $streak day streak",
                            style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Medium),
                        )
                    }
                }

                Spacer(GlanceModifier.height(12.dp))

                Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    if (rings == null || rings.length() == 0) {
                        Text(text = "Open Track Pro to start logging", style = TextStyle(fontSize = 12.sp))
                    } else {
                        for (i in 0 until rings.length()) {
                            val ring = rings.getJSONObject(i)
                            Ring(
                                pct = ring.optDouble("pct", 0.0).toFloat(),
                                value = ring.optString("value"),
                                label = ring.optString("name"),
                                emoji = ring.optString("emoji"),
                                color = Color(ring.optInt("color")),
                                color2 = Color(ring.optInt("color2")),
                            )
                            if (i < rings.length() - 1) Spacer(GlanceModifier.width(14.dp))
                        }
                    }
                }

                if (summary.isNotEmpty()) {
                    Spacer(GlanceModifier.height(12.dp))
                    Text(text = summary, style = TextStyle(fontSize = 11.sp))
                }
            }
        }
    }

    /** One ring: emoji + value centred in a gradient arc, tracker name below. */
    @Composable
    private fun Ring(
        pct: Float,
        value: String,
        label: String,
        emoji: String,
        color: Color,
        color2: Color,
    ) {
        val clamped = pct.coerceIn(0f, 1f)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(modifier = GlanceModifier.size(58.dp), contentAlignment = Alignment.Center) {
                Canvas(modifier = GlanceModifier.size(58.dp)) {
                    val stroke = 6f
                    val arcSize = Size(size.width - stroke, size.height - stroke)
                    val topLeft = Offset(stroke / 2f, stroke / 2f)

                    drawArc(
                        color = Color(0x1F3C3C43),
                        startAngle = 0f,
                        sweepAngle = 360f,
                        useCenter = false,
                        topLeft = topLeft,
                        size = arcSize,
                        style = Stroke(width = stroke),
                    )
                    if (clamped > 0f) {
                        drawArc(
                            brush = Brush.linearGradient(
                                colors = listOf(color, color2),
                                start = Offset.Zero,
                                end = Offset(size.width, size.height),
                            ),
                            startAngle = -90f,
                            sweepAngle = 360f * clamped,
                            useCenter = false,
                            topLeft = topLeft,
                            size = arcSize,
                            style = Stroke(width = stroke, cap = StrokeCap.Round),
                        )
                    }
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = emoji, style = TextStyle(fontSize = 11.sp))
                    Text(
                        text = value,
                        style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = color),
                    )
                }
            }
            Spacer(GlanceModifier.height(5.dp))
            Text(text = label, style = TextStyle(fontSize = 10.sp))
        }
    }

    companion object {
        val SNAPSHOT_KEY = stringPreferencesKey("track_snapshot")

        /** Flutter's shared_preferences lands here, keys prefixed with `flutter.`. */
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val FLUTTER_KEY = "flutter.track.widget.snapshot"

        fun readSnapshot(context: Context): String? =
            context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).getString(FLUTTER_KEY, null)

        /** Called from MainActivity after every Dart-side snapshot write. */
        suspend fun refresh(context: Context) = updateAll(context)
    }
}

class TrackWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TrackWidget()
}
