package com.liqtech.lg_quickrig.lg

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import android.widget.Toast
import com.liqtech.lg_quickrig.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LGHomeWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CLEAN    = "com.liqtech.lg_quickrig.ACTION_CLEAN"
        const val ACTION_RELAUNCH = "com.liqtech.lg_quickrig.ACTION_RELAUNCH"
        const val ACTION_REBOOT   = "com.liqtech.lg_quickrig.ACTION_REBOOT"
        const val ACTION_SHUTDOWN = "com.liqtech.lg_quickrig.ACTION_SHUTDOWN"

        private const val RC_CLEAN    = 10
        private const val RC_RELAUNCH = 11
        private const val RC_REBOOT   = 12
        private const val RC_SHUTDOWN = 13
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        val action = intent.action ?: return
        if (action !in listOf(ACTION_CLEAN, ACTION_RELAUNCH, ACTION_REBOOT, ACTION_SHUTDOWN)) return

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                handleAction(context, action)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private suspend fun handleAction(context: Context, action: String) {
        val creds = LGCredentialStore.load(context)

        if (creds == null) {
            toast(context, "Open the LG QuickRig app and connect once first")
            return
        }

        val label = when (action) {
            ACTION_CLEAN    -> "Clean"
            ACTION_RELAUNCH -> "Relaunch"
            ACTION_REBOOT   -> "Reboot"
            ACTION_SHUTDOWN -> "Shutdown"
            else            -> return
        }

        toast(context, "$label sent to ${creds.host}")

        val command = when (action) {
            ACTION_CLEAN    -> LGSshExecutor.cleanCmd
            ACTION_RELAUNCH -> LGSshExecutor.relaunchCmd
            ACTION_REBOOT   -> LGSshExecutor.rebootCmd(creds.password)
            ACTION_SHUTDOWN -> LGSshExecutor.shutdownCmd(creds.password)
            else            -> return
        }

        val outcome = LGSshExecutor.execute(creds, command)

        // Reboot/shutdown drop the SSH connection by design — don't report
        // that as a failure.
        val expectDrop = action == ACTION_REBOOT || action == ACTION_SHUTDOWN
        if (!expectDrop) {
            toast(context, outcome.fold(
                onSuccess = { "$label done" },
                onFailure = { "$label failed: ${it.message?.take(60)}" },
            ))
        }
    }

    private suspend fun toast(context: Context, message: String) {
        withContext(Dispatchers.Main) {
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.lg_home_widget)
        views.setOnClickPendingIntent(R.id.widget_btn_clean,    actionIntent(context, ACTION_CLEAN,    RC_CLEAN))
        views.setOnClickPendingIntent(R.id.widget_btn_relaunch, actionIntent(context, ACTION_RELAUNCH, RC_RELAUNCH))
        views.setOnClickPendingIntent(R.id.widget_btn_reboot,   actionIntent(context, ACTION_REBOOT,   RC_REBOOT))
        views.setOnClickPendingIntent(R.id.widget_btn_shutdown, actionIntent(context, ACTION_SHUTDOWN, RC_SHUTDOWN))
        return views
    }

    private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, LGHomeWidgetProvider::class.java).apply { this.action = action }
        val flags  = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }
}
