package com.liqtech.lg_quickrig.lg

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import com.liqtech.lg_quickrig.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LGHomeWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_REBOOT   = "com.liqtech.lg_quickrig.ACTION_REBOOT"
        const val ACTION_SYNC     = "com.liqtech.lg_quickrig.ACTION_SYNC"
        const val ACTION_SHUTDOWN = "com.liqtech.lg_quickrig.ACTION_SHUTDOWN"
        const val ACTION_BLANK    = "com.liqtech.lg_quickrig.ACTION_BLANK"

        private const val RC_REBOOT   = 10
        private const val RC_SYNC     = 11
        private const val RC_SHUTDOWN = 12
        private const val RC_BLANK    = 13
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
        if (action !in listOf(ACTION_REBOOT, ACTION_SYNC, ACTION_SHUTDOWN, ACTION_BLANK)) return

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
            pushStatus(context, "Open app -> Settings first")
            return
        }

        pushStatus(context, "Running...")

        val command = when (action) {
            ACTION_REBOOT   -> LGSshExecutor.rebootCmd(creds.password)
            ACTION_SYNC     -> LGSshExecutor.syncCmd
            ACTION_SHUTDOWN -> LGSshExecutor.shutdownCmd(creds.password)
            ACTION_BLANK    -> LGSshExecutor.blankCmd
            else            -> return
        }

        val outcome = LGSshExecutor.execute(creds, command)

        val label = when (action) {
            ACTION_REBOOT   -> "Reboot"
            ACTION_SYNC     -> "Sync"
            ACTION_SHUTDOWN -> "Shutdown"
            ACTION_BLANK    -> "Blank"
            else            -> "Done"
        }

        pushStatus(context, outcome.fold(
            onSuccess = { "$label sent" },
            onFailure = { "Error: ${it.message?.take(40)}" },
        ))
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.lg_home_widget)
        views.setOnClickPendingIntent(R.id.widget_btn_reboot,   actionIntent(context, ACTION_REBOOT,   RC_REBOOT))
        views.setOnClickPendingIntent(R.id.widget_btn_sync,     actionIntent(context, ACTION_SYNC,     RC_SYNC))
        views.setOnClickPendingIntent(R.id.widget_btn_shutdown, actionIntent(context, ACTION_SHUTDOWN, RC_SHUTDOWN))
        views.setOnClickPendingIntent(R.id.widget_btn_blank,    actionIntent(context, ACTION_BLANK,    RC_BLANK))
        return views
    }

    private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, LGHomeWidgetProvider::class.java).apply { this.action = action }
        val flags  = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private suspend fun pushStatus(context: Context, message: String) {
        withContext(Dispatchers.Main) {
            val manager = AppWidgetManager.getInstance(context)
            val ids     = manager.getAppWidgetIds(ComponentName(context, LGHomeWidgetProvider::class.java))
            val views   = buildViews(context)
            for (id in ids) manager.updateAppWidget(id, views)
        }
    }
}
