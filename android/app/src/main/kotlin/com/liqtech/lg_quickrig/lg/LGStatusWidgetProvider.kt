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
import com.liqtech.lg_quickrig.CameraDialogActivity
import com.liqtech.lg_quickrig.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LGStatusWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_REFRESH = "com.liqtech.lg_quickrig.ACTION_STATUS_REFRESH"

        // Extra read by MainActivity to open a camera-control dialog on launch.
        const val EXTRA_CAMERA_ACTION = "lg_camera_action"

        private const val RC_ALARM    = 20
        private const val RC_BTN_BASE = 24

        private const val PREFS_NAME      = "LGQuickRigWidgetPrefs"
        private const val KEY_BUTTONS     = "status_buttons"
        private const val DEFAULT_BUTTONS = "flyto,orbit,overlay"

        private val CELLS = listOf(
            Triple(R.id.status_btn_1, R.id.status_btn_1_icon, R.id.status_btn_1_label),
            Triple(R.id.status_btn_2, R.id.status_btn_2_icon, R.id.status_btn_2_label),
            Triple(R.id.status_btn_3, R.id.status_btn_3_icon, R.id.status_btn_3_label),
        )

        fun currentButtons(context: Context): List<String> =
            (context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_BUTTONS, DEFAULT_BUTTONS) ?: DEFAULT_BUTTONS)
                .split(',')

        fun saveButtons(context: Context, keys: List<String>) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putString(KEY_BUTTONS, keys.joinToString(","))
                .apply()
            // Re-render through the provider's own refresh path.
            context.sendBroadcast(
                Intent(context, LGStatusWidgetProvider::class.java)
                    .apply { action = ACTION_REFRESH })
        }

        private fun refreshIntent(context: Context): PendingIntent {
            val intent = Intent(context, LGStatusWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getBroadcast(context, RC_ALARM, intent, flags)
        }

        /** Shows a floating dialog (Fly To / Orbit / Overlay / Pin) over the
         *  launcher — CameraDialogActivity runs in its own translucent task,
         *  so the main app never comes forward.
         *  Shared with LGHomeWidgetProvider for its dialog buttons. */
        fun appIntent(context: Context, cameraAction: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, CameraDialogActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(EXTRA_CAMERA_ACTION, cameraAction)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getActivity(context, requestCode, intent, flags)
        }

        private fun scheduleAlarm(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.setRepeating(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 5 * 60 * 1000L,
                5 * 60 * 1000L,
                refreshIntent(context),
            )
        }

        private fun cancelAlarm(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.cancel(refreshIntent(context))
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleAlarm(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelAlarm(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        // AlarmManager alarms do not survive a device reboot, and onEnabled
        // only fires when the FIRST widget is placed — so without this the
        // 5-minute auto-refresh died permanently at the next restart and only
        // came back if the widget was removed and re-added. setRepeating with
        // an equal PendingIntent replaces rather than stacks, so re-arming on
        // every update is safe.
        scheduleAlarm(context)

        // goAsync() keeps the receiver alive across the ping. Without it the
        // broadcast completes immediately and the process can be killed
        // mid-refresh, stranding the widget on "Checking".
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                refreshAll(context)
            } finally {
                pendingResult.finish()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            // Both the 5-minute alarm and the user tapping the header land
            // here, and both mean "check for real" rather than reuse a cached
            // answer.
            LGSshExecutor.invalidatePingCache()
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

    private suspend fun refreshAll(context: Context) {
        val creds = LGCredentialStore.load(context)

        if (creds == null) {
            applyViews(context) { views ->
                views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_pending)
                views.setTextViewText(R.id.status_label, "Not configured")
                views.setTextViewText(R.id.status_host, "Open app to add credentials")
            }
            return
        }

        applyViews(context) { views ->
            views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_pending)
            views.setTextViewText(R.id.status_label, "Checking")
            views.setTextViewText(R.id.status_host, creds.host)
        }

        val online = LGSshExecutor.ping(creds)

        applyViews(context) { views ->
            if (online) {
                views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_online)
                views.setTextViewText(R.id.status_label, "Connected")
            } else {
                views.setImageViewResource(R.id.status_indicator, R.drawable.status_circle_offline)
                views.setTextViewText(R.id.status_label, "Disconnected")
            }
            views.setTextViewText(R.id.status_host, creds.host)
        }
    }

    private suspend fun applyViews(context: Context, block: (RemoteViews) -> Unit) {
        withContext(Dispatchers.Main) {
            val manager = AppWidgetManager.getInstance(context)
            val ids     = manager.getAppWidgetIds(ComponentName(context, LGStatusWidgetProvider::class.java))
            if (ids.isEmpty()) return@withContext
            val views = RemoteViews(context.packageName, R.layout.lg_status_widget)
            views.setOnClickPendingIntent(R.id.status_header, refreshIntent(context))
            currentButtons(context).take(3).forEachIndexed { i, key ->
                val action = LGHomeWidgetProvider.actionFor(key) ?: return@forEachIndexed
                val (cell, icon, label) = CELLS[i]
                views.setTextViewText(icon, action.symbol)
                views.setTextColor(icon, action.textColor)
                views.setTextViewText(label, action.label)
                views.setInt(cell, "setBackgroundColor", action.bgColor)
                views.setOnClickPendingIntent(cell,
                    LGHomeWidgetProvider.clickIntent(context, action, RC_BTN_BASE + i))
            }
            block(views)
            for (id in ids) manager.updateAppWidget(id, views)
        }
    }
}
