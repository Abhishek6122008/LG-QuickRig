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

/**
 * AppWidgetProvider for the LG QuickRig Command Bar (4×1 home screen widget).
 *
 * ── Android widget execution model ───────────────────────────────────────────
 * This class is a BroadcastReceiver. The launcher inflates the widget layout
 * in its own process (RemoteViews), but all button taps become Intents that the
 * system delivers to onReceive() here, in the APP process.
 *
 * Button tap flow:
 *   Launcher tap → PendingIntent → onReceive() (app process, main thread)
 *     → goAsync() + Dispatchers.IO coroutine → LGSshExecutor.execute()
 *     → RemoteViews.setTextViewText() to update status → AppWidgetManager.updateAppWidget()
 *
 * goAsync() extends the BroadcastReceiver deadline from 10 s to ~30–60 s, which
 * is enough for a single SSH command. For commands that can time out longer
 * (e.g., reboot chains), WorkManager would be the right upgrade path.
 * ─────────────────────────────────────────────────────────────────────────────
 */
class LGHomeWidgetProvider : AppWidgetProvider() {

    companion object {
        // Custom action strings — sent as Intent extras from each button's PendingIntent.
        // requestCode must be unique per action so the OS doesn't collapse the intents.
        const val ACTION_REBOOT   = "com.liqtech.lg_quickrig.ACTION_REBOOT"
        const val ACTION_SYNC     = "com.liqtech.lg_quickrig.ACTION_SYNC"
        const val ACTION_SHUTDOWN = "com.liqtech.lg_quickrig.ACTION_SHUTDOWN"
        const val ACTION_BLANK    = "com.liqtech.lg_quickrig.ACTION_BLANK"

        private const val RC_REBOOT   = 10
        private const val RC_SYNC     = 11
        private const val RC_SHUTDOWN = 12
        private const val RC_BLANK    = 13
    }

    // ── AppWidgetProvider callbacks ───────────────────────────────────────────

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        // Called when the widget is first added to the home screen and whenever
        // the system needs a full redraw (e.g., after reboot).
        for (id in appWidgetIds) {
            val views = buildViews(context)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)   // lets the framework handle APPWIDGET_UPDATE etc.

        val action = intent.action ?: return
        if (action !in listOf(ACTION_REBOOT, ACTION_SYNC, ACTION_SHUTDOWN, ACTION_BLANK)) return

        val pendingResult = goAsync()   // keeps the receiver alive past the 10 s limit

        CoroutineScope(Dispatchers.IO).launch {
            try {
                handleAction(context, action)
            } finally {
                pendingResult.finish()  // must always be called to avoid ANR
            }
        }
    }

    // ── Action dispatch ───────────────────────────────────────────────────────

    private suspend fun handleAction(context: Context, action: String) {
        val creds = LGCredentialStore.load(context)

        if (creds == null) {
            // No credentials saved yet — show a prompt in the widget status.
            pushStatus(context, "Open app → Settings first")
            return
        }

        pushStatus(context, "Running…")

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

        val status = outcome.fold(
            onSuccess = { "$label sent ✓" },
            onFailure = { "Error: ${it.message?.take(40)}" },
        )
        pushStatus(context, status)
    }

    // ── RemoteViews helpers ───────────────────────────────────────────────────

    /**
     * Builds a fresh RemoteViews with all four button PendingIntents attached.
     *
     * Each button sends a broadcast to this provider with a unique action string.
     * The requestCode must differ per action or Android will reuse the same
     * PendingIntent (collapsing different actions into one).
     */
    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.lg_home_widget)

        views.setOnClickPendingIntent(R.id.widget_btn_reboot,
            actionIntent(context, ACTION_REBOOT,   RC_REBOOT))
        views.setOnClickPendingIntent(R.id.widget_btn_sync,
            actionIntent(context, ACTION_SYNC,     RC_SYNC))
        views.setOnClickPendingIntent(R.id.widget_btn_shutdown,
            actionIntent(context, ACTION_SHUTDOWN, RC_SHUTDOWN))
        views.setOnClickPendingIntent(R.id.widget_btn_blank,
            actionIntent(context, ACTION_BLANK,    RC_BLANK))

        return views
    }

    private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, LGHomeWidgetProvider::class.java).apply {
            this.action = action
        }
        // FLAG_IMMUTABLE is required on API 31+; safe to set on API 23+ as well.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    /**
     * Updates every instance of this widget with a new status line without
     * rebuilding the button PendingIntents (those are already set).
     * Called from the background coroutine after an SSH command completes.
     */
    private suspend fun pushStatus(context: Context, message: String) {
        withContext(Dispatchers.Main) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, LGHomeWidgetProvider::class.java)
            )
            // Rebuild the full view so buttons remain wired after a status update.
            val views = buildViews(context)
            for (id in ids) manager.updateAppWidget(id, views)
        }
    }
}
