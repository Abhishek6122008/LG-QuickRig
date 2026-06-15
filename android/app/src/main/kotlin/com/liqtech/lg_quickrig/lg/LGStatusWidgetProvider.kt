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
import com.liqtech.lg_quickrig.MainActivity
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

        private const val RC_ALARM = 20
        private const val RC_FLYTO = 24
        private const val RC_ORBIT = 25

        private fun refreshIntent(context: Context): PendingIntent {
            val intent = Intent(context, LGStatusWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getBroadcast(context, RC_ALARM, intent, flags)
        }

        /** Opens the app to a camera-control dialog (Fly To / Orbit). */
        private fun appIntent(context: Context, cameraAction: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
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
        CoroutineScope(Dispatchers.IO).launch {
            refreshAll(context)
        }
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
            views.setOnClickPendingIntent(R.id.status_header,    refreshIntent(context))
            views.setOnClickPendingIntent(R.id.status_btn_flyto, appIntent(context, "flyto", RC_FLYTO))
            views.setOnClickPendingIntent(R.id.status_btn_orbit, appIntent(context, "orbit", RC_ORBIT))
            block(views)
            for (id in ids) manager.updateAppWidget(id, views)
        }
    }
}
