package com.liqtech.lg_quickrig.lg

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Platform channel bridge: Dart (main Flutter engine) ←→ Kotlin (native Android).
 *
 * Channel name: "com.liqtech.lg_quickrig/commands"
 *
 * ── When is this used? ───────────────────────────────────────────────────────
 * This channel is wired into the MAIN Flutter engine by [MainActivity]. It
 * enables the running Flutter UI to call native operations, and for native code
 * to call back into the live Dart isolate.
 *
 * Note: App Widgets and Quick Settings tiles do NOT use this channel — they
 * call [LGSshExecutor] directly, because the main engine may not be running
 * when a widget button is pressed.
 *
 * ── Supported methods ────────────────────────────────────────────────────────
 *
 *   executeSSHCommand
 *     args    → { "command": String }   (raw shell command)
 *     returns → String (stdout/stderr)
 *     errors  → NO_CREDS | SSH_ERROR
 *
 *   getConnectionStatus
 *     args    → none
 *     returns → "unconfigured" | "configured"
 *               ("configured" only means credentials exist, not that the
 *               node is reachable — use ping if you need a live check)
 *
 * ── Dart side call example ───────────────────────────────────────────────────
 *   const _ch = MethodChannel('com.liqtech.lg_quickrig/commands');
 *   final out = await _ch.invokeMethod<String>('executeSSHCommand',
 *                   {'command': "echo hello"});
 * ─────────────────────────────────────────────────────────────────────────────
 */
class LGCommandChannel(private val context: Context) {

    companion object {
        const val CHANNEL = "com.liqtech.lg_quickrig/commands"
    }

    private val scope = CoroutineScope(Dispatchers.IO)

    fun setup(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                // ── executeSSHCommand ─────────────────────────────────────────
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

                    // SSH is blocking I/O — move off the platform thread.
                    // result.success / result.error must be called on the main thread.
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

                // ── getConnectionStatus ───────────────────────────────────────
                "getConnectionStatus" -> {
                    // Credential check is synchronous and fast (in-process Keystore read).
                    val status = if (LGCredentialStore.hasCredentials(context))
                        "configured" else "unconfigured"
                    result.success(status)
                }

                else -> result.notImplemented()
            }
        }
    }
}
