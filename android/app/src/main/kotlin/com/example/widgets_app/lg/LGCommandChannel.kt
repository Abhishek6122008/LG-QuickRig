package com.example.widgets_app.lg

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel that lets Dart code trigger native Android operations.
 *
 * Channel name: "com.liqtech.lg_quickrig/commands"
 *
 * This channel is the bridge used by:
 *  - Home screen App Widgets (which run in a separate process and call back
 *    into a background Flutter engine).
 *  - Quick Settings tiles, which are bound services and cannot open the main
 *    Activity directly.
 *
 * ── How platform channels work (primer for Flutter devs) ──────────────────
 *
 * Flutter side (Dart):
 *   ```dart
 *   const _channel = MethodChannel('com.liqtech.lg_quickrig/commands');
 *   final result = await _channel.invokeMethod<String>(
 *     'executeSSHCommand',
 *     {'command': 'reboot'},
 *   );
 *   ```
 *
 * Native side (this file):
 *   Flutter calls arrive on the platform thread via [setMethodCallHandler].
 *   Heavy work (network I/O, SSH) must be dispatched to a background
 *   coroutine or thread so the platform thread is never blocked.
 *
 * Both sides share a binary messenger provided by the FlutterEngine.
 * ─────────────────────────────────────────────────────────────────────────
 */
class LGCommandChannel(private val context: Context) {

    companion object {
        const val CHANNEL = "com.liqtech.lg_quickrig/commands"
    }

    /**
     * Registers the method-call handler on [messenger].
     * Call this from [MainActivity.configureFlutterEngine].
     */
    fun setup(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {

                // ── executeSSHCommand ──────────────────────────────────────
                // Dart sends this when a widget/tile needs to run a raw
                // command on the LG node without the main UI being open.
                //
                // Expected arguments:  { "command": String }
                // Returns:             String (stdout) or error
                //
                // TODO: Move the SSH credentials lookup + execution into a
                // Kotlin coroutine (kotlinx.coroutines) or WorkManager job so
                // the platform thread is not blocked.
                "executeSSHCommand" -> {
                    val command = call.argument<String>("command")
                    if (command.isNullOrBlank()) {
                        result.error(
                            "INVALID_ARG",
                            "Argument 'command' is required and must not be blank.",
                            null
                        )
                    } else {
                        // TODO: Retrieve stored credentials (host/user/pass)
                        //       from EncryptedSharedPreferences, open an SSH
                        //       session on a background thread, then call
                        //       result.success(output) or result.error(...).
                        result.success("STUB: would execute → $command")
                    }
                }

                // ── getConnectionStatus ────────────────────────────────────
                // Allows tiles/widgets to poll whether a saved credential set
                // exists before showing an "execute" action.
                "getConnectionStatus" -> {
                    // TODO: Return real credential-existence check.
                    result.success("unconfigured")
                }

                else -> result.notImplemented()
            }
        }
    }
}
