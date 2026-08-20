package com.liqtech.lg_quickrig.lg

import android.app.StatusBarManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.drawable.Icon
import android.os.Build
import com.liqtech.lg_quickrig.R
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LGCommandChannel(private val context: Context) {

    companion object {
        const val CHANNEL = "com.liqtech.lg_quickrig/commands"
    }

    private val scope = CoroutineScope(Dispatchers.IO)

    fun setup(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                "executeSSHCommand" -> {
                    val command = call.argument<String>("command")
                    if (command.isNullOrBlank()) {
                        result.error("INVALID_ARG", "'command' must not be blank.", null)
                        return@setMethodCallHandler
                    }

                    val creds = LGCredentialStore.load(context)
                    if (creds == null) {
                        result.error("NO_CREDS", "No LG credentials configured.", null)
                        return@setMethodCallHandler
                    }

                    scope.launch {
                        val outcome = LGSshExecutor.execute(creds, command)
                        withContext(Dispatchers.Main) {
                            outcome.fold(
                                onSuccess = { result.success(it) },
                                onFailure = { result.error("SSH_ERROR", it.message, null) },
                            )
                        }
                    }
                }

                "getConnectionStatus" -> {
                    val status = if (LGCredentialStore.hasCredentials(context))
                        "configured" else "unconfigured"
                    result.success(status)
                }

                "saveCredentials" -> {
                    val host = call.argument<String>("host")
                    if (host.isNullOrBlank()) {
                        result.error("INVALID_ARG", "'host' must not be blank.", null)
                        return@setMethodCallHandler
                    }
                    val port      = call.argument<String>("port")?.toIntOrNull() ?: 22
                    val username  = call.argument<String>("username") ?: "lg"
                    val password  = call.argument<String>("password") ?: ""
                    val nodeCount = call.argument<String>("nodeCount")?.toIntOrNull() ?: 3

                    scope.launch {
                        LGCredentialStore.save(context, host, port, username, password, nodeCount)
                        withContext(Dispatchers.Main) { result.success(true) }
                    }
                }

                "getWidgetButtons" -> {
                    val buttons = if (call.argument<String>("widget") == "status")
                        LGStatusWidgetProvider.currentButtons(context)
                    else
                        LGHomeWidgetProvider.currentButtons(context)
                    result.success(buttons)
                }

                "saveWidgetButtons" -> {
                    val status = call.argument<String>("widget") == "status"
                    val expected = if (status) 3 else 4
                    val keys = call.argument<List<String>>("buttons")
                    if (keys == null || keys.size != expected) {
                        result.error("INVALID_ARG", "'buttons' must be $expected keys.", null)
                        return@setMethodCallHandler
                    }
                    if (status) LGStatusWidgetProvider.saveButtons(context, keys)
                    else LGHomeWidgetProvider.saveButtons(context, keys)
                    result.success(true)
                }

                "pinWidget" -> {
                    val provider = when (call.argument<String>("widget")) {
                        "status" -> LGStatusWidgetProvider::class.java
                        else     -> LGHomeWidgetProvider::class.java
                    }
                    val manager = AppWidgetManager.getInstance(context)
                    val ok = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(
                                ComponentName(context, provider), null, null)
                    result.success(ok)
                }

                // Android 13+ can prompt the user to add the tile. Below that
                // the only route is pulling down the shade and editing the
                // tile list by hand, which is what the app tells them to do.
                "requestAddTile" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val statusBar = context.getSystemService(StatusBarManager::class.java)
                        if (statusBar == null) {
                            result.success(false)
                        } else {
                            statusBar.requestAddTileService(
                                ComponentName(context, LGQuickSettingsTile::class.java),
                                context.getString(R.string.qs_tile_label),
                                Icon.createWithResource(context, R.drawable.ic_power),
                                { it.run() },
                                {},
                            )
                            result.success(true)
                        }
                    } else {
                        result.success(false)
                    }
                }

                "clearCredentials" -> {
                    scope.launch {
                        LGCredentialStore.clear(context)
                        withContext(Dispatchers.Main) { result.success(true) }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
