package com.liqtech.lg_quickrig.lg

import android.content.Context
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

                else -> result.notImplemented()
            }
        }
    }
}
