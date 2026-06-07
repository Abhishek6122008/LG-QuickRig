package com.liqtech.lg_quickrig.lg

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import com.liqtech.lg_quickrig.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * AppWidgetProvider for the LG QuickRig Live Status widget (2x2 home screen widget).
 *
 * ── What it shows ─────────────────────────────────────────────────────────────
 *   - A colored dot:  green (online) / red (offline) / grey (checking / unconfigured)
 *   - Status label:   "Connected", "Disconnected", "Checking", or "Not configured"
 *   - Host IP (small text below the label)
 *   - Last-updated timestamp
 *
 * ── Auto-refresh model ────────────────────────────────────────────────────────
 * Android's updatePeriodMillis has a 30-minute OS floor, so for a 5-minute
 * refresh we use AlarmManager with ELAPSED_REALTIME (not _WAKEUP) — the alarm
 * fires when the device is already awake and will not drain the battery by
 * waking a sleeping screen.
 *
 *   onEnabled()  → schedule repeating alarm (5 min)
 *   onDisabled() → cancel the alarm
 *   onReceive()  → handle both APPWIDGET_UPDATE and ACTION_REFRESH
 *
 * ── Execution model ───────────────────────────────────────────────────────────
 * onReceive() runs on the main thread with a 10s deadline. We call goAsync()
 * to extend that deadline while the SSH ping runs on Dispatchers.IO.
 * ─────────────────────────────────────────────────────────────────────────────
 */
class LGStatusWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_REFRESH = "com.liqtech.lg_quickrig.ACTION_STATUS_REFRESH"

        private const val RC_ALARM = 20
        private val TIME_FMT = SimpleDateFormat("HH:mm", Locale.getDefault())

        private fun alarmIntent(context: Context): PendingIntent {
            val intent = Intent(context, LGStatusWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getBroadcast(context, RC_ALARM, intent, flags)
        }

        private fun scheduleAlarm(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = alarmIntent(context)
            // ELAPSED_REALTIME fires when the device is already awake — no battery drain.
            alarm.setRepeating(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 5 * 60 * 1000L,
                5 * 60 * 1000L,
                pending,
            )
        }

        private fun cancelAlarm(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.cancel(alarmIntent(context))
        }
    }

    // ── AppWidgetProvider lifecycle ───────────────────────────────────────────

    /** Called when the first instance of this widget is added to the home screen. */
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleAlarm(context)
    }

    /** Called when the last instance of this widget is removed. */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelAlarm(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        refreshAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val pendingResult = goAsync()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    refreshAll(context)
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }

    // ── Core refresh logic ────────────────────────────────────────────────────

    private suspend fun refreshAll(context: Context) {
        val creds = LGCredentialStore.load(context)

        if (creds == null) {
            applyViews(context) { views ->
                views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_pending)
                views.setTextViewText(R.id.status_label, "Not configured")
                views.setTextViewText(R.id.status_host, "Open app to add credentials")
                views.setTextViewText(R.id.status_time, "")
            }
            return
        }

        // Show "Checking" state while the ping is in flight.
        applyViews(context) { views ->
            views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_pending)
            views.setTextViewText(R.id.status_label, "Checking")
            views.setTextViewText(R.id.status_host, creds.host)
            views.setTextViewText(R.id.status_time, "")
        }

        val online = LGSshExecutor.ping(creds)
        val time = TIME_FMT.format(Date())

        applyViews(context) { views ->
            if (online) {
                views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_online)
                views.setTextViewText(R.id.status_label, "Connected")
            } else {
                views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_offline)
                views.setTextViewText(R.id.status_label, "Disconnected")
            }
            views.setTextViewText(R.id.status_host, creds.host)
            views.setTextViewText(R.id.status_time, "Updated $time")
        }
    }

    // ── RemoteViews helper ────────────────────────────────────────────────────

    /**
     * Builds a RemoteViews, applies [block] to configure it, then pushes it
     * to every active instance of this widget. Must be called from a coroutine
     * since [withContext] is used to switch to the main thread for the update.
     */
    private suspend fun applyViews(context: Context, block: (RemoteViews) -> Unit) {
        withContext(Dispatchers.Main) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, LGStatusWidgetProvider::class.java)
            )
            if (ids.isEmpty()) return@withContext
            val views = RemoteViews(context.packageName, R.layout.lg_status_widget)
            block(views)
            for (id in ids) manager.updateAppWidget(id, views)
        }
    }
}
