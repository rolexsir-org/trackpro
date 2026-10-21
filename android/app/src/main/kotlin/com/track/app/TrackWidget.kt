package com.track.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Paint
import android.graphics.RectF
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
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
import androidx.glance.unit.ColorProvider
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
 * Rendering note: Glance has no Canvas composable (it compiles down to
 * RemoteViews), so the arcs are drawn into a small Bitmap with android.graphics
 * and shown through [Image]. An earlier revision of this file imported
 * `androidx.glance.Canvas`, which does not exist — it could never have compiled.
 *
 * Every tap opens MainActivity: the widget is a *door* into the app, which is
 * the whole point of shipping one.
 */
class TrackWidget : GlanceAppWidget() {

    override val sizeMode: SizeMode = SizeMode.Responsive(
        setOf(DpSize(160.dp, 110.dp), DpSize(250.dp, 110.dp), DpSize(250.dp, 220.dp)),
    )

    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Read once from Flutter's prefs, then keep it in the widget's own state
        // so system-triggered re-renders (resize, theme change) are free.
        val snapshot = readSnapshot(context)
        updateAppWidgetState(context, id) { prefs ->
            prefs[SNAPSHOT_KEY] = snapshot.orEmpty()
        }

        provideContent {
            val state = currentState<Preferences>()
            val payload = state[SNAPSHOT_KEY]
                ?.takeIf { it.isNotBlank() }
                ?.let { runCatching { JSONObject(it) }.getOrNull() }
            WidgetContent(payload, context)
        }
    }

    @Composable
    private fun WidgetContent(payload: JSONObject?, context: Context) {
        val rings = payload?.optJSONArray("rings")
        val streak = payload?.optInt("streak", 0) ?: 0
        val summary = payload?.optString("summary").orEmpty()
        val size = LocalSize.current
        val compact = size.height < 150.dp

        GlanceTheme {
            Column(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .appWidgetBackground()
                    .background(ColorProvider(Color(0xFF111111)))
                    .cornerRadius(20.dp)
                    .padding(if (compact) 10.dp else 16.dp)
                    .clickable(actionStartActivity<MainActivity>()),
            ) {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Track Pro",
                        style = TextStyle(
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(Color(0xFFF5F5F5)),
                        ),
                    )
                    Spacer(GlanceModifier.defaultWeight())
                    if (streak > 0) {
                        Text(
                            text = "$streak-day streak",
                            style = TextStyle(
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                color = ColorProvider(Color(0xFFFF7A18)),
                            ),
                        )
                    }
                }

                Spacer(GlanceModifier.height(if (compact) 6.dp else 12.dp))

                Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    if (rings == null || rings.length() == 0) {
                        Text(
                            text = "Open Track Pro to start logging",
                            style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color(0xFFA8A8A8))),
                        )
                    } else {
                        // A launcher can size this widget as narrowly as 160dp. One
                        // ring remains readable there; three fit only in the wider size.
                        val count = minOf(rings.length(), if (size.width < 220.dp) 1 else 3)
                        for (i in 0 until count) {
                            val ring = rings.getJSONObject(i)
                            Ring(
                                context = context,
                                pct = ring.optDouble("pct", 0.0).toFloat(),
                                value = ring.optString("value"),
                                label = ring.optString("name"),
                            )
                            if (i < count - 1) Spacer(GlanceModifier.width(14.dp))
                        }
                    }
                }

                if (!compact && summary.isNotEmpty()) {
                    Spacer(GlanceModifier.height(12.dp))
                    Text(
                        text = summary,
                        style = TextStyle(fontSize = 11.sp, color = ColorProvider(Color(0xFFA8A8A8))),
                    )
                }
            }
        }
    }

    /** One ring: a compact value inside a solid orange progress arc. */
    @Composable
    private fun Ring(
        context: Context,
        pct: Float,
        value: String,
        label: String,
    ) {
        val clamped = pct.coerceIn(0f, 1f)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(modifier = GlanceModifier.size(58.dp), contentAlignment = Alignment.Center) {
                Image(
                    provider = ImageProvider(ringBitmap(context, clamped)),
                    contentDescription = null,
                    modifier = GlanceModifier.size(58.dp),
                )
                Text(
                    text = value,
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color(0xFFFF7A18)),
                    ),
                )
            }
            Spacer(GlanceModifier.height(5.dp))
            Text(
                text = label,
                style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color(0xFFA8A8A8))),
            )
        }
    }

    /** Draws a neutral track and a single solid accent arc into a bitmap. */
    private fun ringBitmap(
        context: Context,
        pct: Float,
        sizeDp: Float = 58f,
        strokeDp: Float = 6f,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val px = (sizeDp * density).toInt().coerceAtLeast(2)
        val stroke = strokeDp * density
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        val rect = RectF(stroke / 2f, stroke / 2f, px - stroke / 2f, px - stroke / 2f)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }

        paint.color = 0xFF272727.toInt()
        canvas.drawArc(rect, 0f, 360f, false, paint)

        if (pct > 0f) {
            paint.color = 0xFFFF7A18.toInt()
            canvas.drawArc(rect, -90f, 360f * pct, false, paint)
        }
        return bitmap
    }

    companion object {
        val SNAPSHOT_KEY = stringPreferencesKey("track_snapshot")

        /** Flutter's shared_preferences lands here, keys prefixed with `flutter.`. */
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val FLUTTER_KEY = "flutter.track.widget.snapshot"

        fun readSnapshot(context: Context): String? =
            context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).getString(FLUTTER_KEY, null)

        /** Called from MainActivity after every Dart-side snapshot write. */
        suspend fun refresh(context: Context) = TrackWidget().updateAll(context)
    }
}

class TrackWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TrackWidget()
}
