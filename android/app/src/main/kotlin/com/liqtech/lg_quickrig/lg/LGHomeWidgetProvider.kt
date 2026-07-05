package com.liqtech.lg_quickrig.lg

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
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

/** One choosable widget button. [broadcast] null → opens an app dialog. */
internal data class WidgetAction(
    val key: String,
    val label: String,
    val symbol: String,
    val textColor: Int,
    val bgColor: Int,
    val broadcast: String?,
)

class LGHomeWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_CLEAN    = "com.liqtech.lg_quickrig.ACTION_CLEAN"
        const val ACTION_RELAUNCH = "com.liqtech.lg_quickrig.ACTION_RELAUNCH"
        const val ACTION_REBOOT   = "com.liqtech.lg_quickrig.ACTION_REBOOT"
        const val ACTION_SHUTDOWN = "com.liqtech.lg_quickrig.ACTION_SHUTDOWN"
        const val ACTION_SYNC     = "com.liqtech.lg_quickrig.ACTION_SYNC"
        const val ACTION_BLANK    = "com.liqtech.lg_quickrig.ACTION_BLANK"

        private const val PREFS_NAME  = "LGQuickRigWidgetPrefs"
        private const val KEY_BUTTONS = "home_buttons"
        private const val DEFAULT_BUTTONS = "clean,relaunch,reboot,shutdown"

        // Keys must match _WidgetButtonsDialog.actions on the Dart side.
        private val CATALOG = listOf(
            WidgetAction("clean",    "Clean",    "⌫", 0xFF00897B.toInt(), 0x1A00B5A3, ACTION_CLEAN),
            WidgetAction("relaunch", "Relaunch", "⟳", 0xFF2962FF.toInt(), 0x1A3D7EFF, ACTION_RELAUNCH),
            WidgetAction("reboot",   "Reboot",   "↺", 0xFFE07B00.toInt(), 0x1AFF9500, ACTION_REBOOT),
            // ◉ not ⏻ — the U+23FB power symbol is missing from the widget font.
            WidgetAction("shutdown", "Shutdown", "◉", 0xFFD93025.toInt(), 0x1AFF3B30, ACTION_SHUTDOWN),
            WidgetAction("sync",     "Sync",     "⇄", 0xFF12A4AF.toInt(), 0x1A12A4AF, ACTION_SYNC),
            WidgetAction("blank",    "Blank",    "□", 0xFF5F6368.toInt(), 0x1A5F6368, ACTION_BLANK),
            WidgetAction("overlay",  "Overlay",  "▣", 0xFF9334E6.toInt(), 0x1A9334E6, null),
            WidgetAction("flyto",    "Fly To",   "◎", 0xFF00897B.toInt(), 0x1A00B5A3, null),
            WidgetAction("orbit",    "Orbit",    "⟲", 0xFF2962FF.toInt(), 0x1A3D7EFF, null),
            WidgetAction("pin",      "Pin",      "⚑", 0xFFD93025.toInt(), 0x1AFF3B30, null),
        )

        private val CELLS = listOf(
            Triple(R.id.widget_btn_1, R.id.widget_btn_1_icon, R.id.widget_btn_1_label),
            Triple(R.id.widget_btn_2, R.id.widget_btn_2_icon, R.id.widget_btn_2_label),
            Triple(R.id.widget_btn_3, R.id.widget_btn_3_icon, R.id.widget_btn_3_label),
            Triple(R.id.widget_btn_4, R.id.widget_btn_4_icon, R.id.widget_btn_4_label),
        )

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        fun currentButtons(context: Context): List<String> =
            (prefs(context).getString(KEY_BUTTONS, DEFAULT_BUTTONS) ?: DEFAULT_BUTTONS)
                .split(',')

        fun saveButtons(context: Context, keys: List<String>) {
            prefs(context).edit()
                .putString(KEY_BUTTONS, keys.joinToString(","))
                .apply()
            refresh(context)
        }

        /** Re-renders every placed Command Bar widget from the saved config. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, LGHomeWidgetProvider::class.java))
            for (id in ids) manager.updateAppWidget(id, buildViews(context))
        }

        private fun pendingFlags() = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        internal fun actionFor(key: String): WidgetAction? = CATALOG.find { it.key == key }

        /** Tap intent for a catalog action — SSH broadcast or floating dialog.
         *  Request codes must be unique per cell: filterEquals ignores extras,
         *  so two dialog intents with the same code would collapse into one. */
        internal fun clickIntent(
            context: Context,
            action: WidgetAction,
            requestCode: Int,
        ): PendingIntent = if (action.broadcast != null) {
            val broadcast = Intent(context, LGHomeWidgetProvider::class.java)
                .apply { this.action = action.broadcast }
            PendingIntent.getBroadcast(context, requestCode, broadcast, pendingFlags())
        } else {
            LGStatusWidgetProvider.appIntent(context, action.key, requestCode)
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.lg_home_widget)
            currentButtons(context).take(4).forEachIndexed { i, key ->
                val action = actionFor(key) ?: return@forEachIndexed
                val (cell, icon, label) = CELLS[i]
                views.setTextViewText(icon, action.symbol)
                views.setTextColor(icon, action.textColor)
                views.setTextViewText(label, action.label)
                views.setInt(cell, "setBackgroundColor", action.bgColor)
                val rc = if (action.broadcast != null) 10 + i else 30 + i
                views.setOnClickPendingIntent(cell, clickIntent(context, action, rc))
            }
            return views
        }
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
        if (action !in listOf(
                ACTION_CLEAN, ACTION_RELAUNCH, ACTION_REBOOT,
                ACTION_SHUTDOWN, ACTION_SYNC, ACTION_BLANK)) return

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
            ACTION_SYNC     -> "Sync"
            ACTION_BLANK    -> "Blank"
            else            -> return
        }

        toast(context, "$label sent to ${creds.host}")

        val command = when (action) {
            ACTION_CLEAN    -> LGSshExecutor.cleanCmd
            ACTION_RELAUNCH -> LGSshExecutor.relaunchCmd
            ACTION_REBOOT   -> LGSshExecutor.rebootCmd(creds.password, creds.nodeCount)
            ACTION_SHUTDOWN -> LGSshExecutor.shutdownCmd(creds.password, creds.nodeCount)
            ACTION_SYNC     -> LGSshExecutor.syncCmd
            ACTION_BLANK    -> LGSshExecutor.blankCmd
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
}
