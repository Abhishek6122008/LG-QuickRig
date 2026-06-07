package com.liqtech.lg_quickrig.lg

import com.jcraft.jsch.ChannelExec
import com.jcraft.jsch.JSch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Executes SSH commands on the LG master node from Kotlin (widgets, tiles).
 *
 * Uses JSch — a pure-Java SSH2 library — so no native binaries are required.
 * Every public function is a suspend fun that switches to Dispatchers.IO, so
 * callers can safely invoke it from any coroutine without blocking the UI.
 *
 * ── Why a separate Kotlin SSH client? ────────────────────────────────────────
 * Android App Widgets and Quick Settings tiles run in their own processes or as
 * bound services. They cannot share the live SSH connection that the Flutter
 * Dart isolate holds. Opening a short-lived JSch session per action is the
 * correct pattern: cheap for fire-and-forget cluster commands.
 * ─────────────────────────────────────────────────────────────────────────────
 */
object LGSshExecutor {

    private const val CONNECT_TIMEOUT_MS = 10_000
    private const val EXEC_TIMEOUT_MS   = 15_000

    /**
     * Opens an SSH session, runs [command] on the master node, and returns the
     * trimmed stdout. Stderr is captured only if stdout is empty (same
     * convention as [LGSSHClient] on the Dart side).
     *
     * Returns [Result.failure] if the connection or command fails.
     */
    suspend fun execute(
        creds: LGCredentials,
        command: String,
        timeoutMs: Int = EXEC_TIMEOUT_MS,
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val jsch   = JSch()
            val session = jsch.getSession(creds.username, creds.host, creds.port)
            session.setPassword(creds.password)
            // Equivalent to -o StrictHostKeyChecking=no used by the Dart side.
            session.setConfig("StrictHostKeyChecking", "no")
            session.timeout = CONNECT_TIMEOUT_MS
            session.connect()

            // ChannelExec: non-interactive command channel — no PTY allocated.
            // sudo -S reads the password from stdin instead of a TTY.
            val channel = session.openChannel("exec") as ChannelExec

            channel.setCommand(command)

            // Must capture the stream reference BEFORE calling channel.connect()
            // — JSch replaces the stream after connect.
            val stdout = channel.inputStream
            val stderr = channel.errStream

            channel.connect()

            // Wait for the command to complete (channel.isClosed polls exit status).
            val deadline = System.currentTimeMillis() + timeoutMs
            while (!channel.isClosed && System.currentTimeMillis() < deadline) {
                Thread.sleep(50)
            }

            val out = stdout.bufferedReader().readText().trim()
            val err = stderr.bufferedReader().readText().trim()

            channel.disconnect()
            session.disconnect()

            // Mirror the Dart convention: prefer stdout, fall back to stderr prefix.
            when {
                out.isNotEmpty() -> out
                err.isNotEmpty() -> "[stderr] $err"
                else             -> ""
            }
        }
    }

    /**
     * Attempts an SSH handshake without running any command.
     * Returns true if the LG node accepts the credentials; false otherwise.
     * Used by [LGQuickSettingsTile] to update the tile's active/inactive state.
     */
    suspend fun ping(creds: LGCredentials): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            val jsch    = JSch()
            val session = jsch.getSession(creds.username, creds.host, creds.port)
            session.setPassword(creds.password)
            session.setConfig("StrictHostKeyChecking", "no")
            session.timeout = 8_000
            session.connect()
            session.disconnect()
        }.isSuccess
    }

    // ── Convenience command builders ──────────────────────────────────────────

    /** Reboots the master node. Connection will drop immediately — that's expected. */
    fun rebootCmd(password: String) =
        "echo '${shellEscape(password)}' | sudo -S reboot"

    /** Shuts down the master node. */
    fun shutdownCmd(password: String) =
        "echo '${shellEscape(password)}' | sudo -S shutdown -h now"

    /** Runs the LG sync script (paths confirmed on this installation). */
    val syncCmd =
        "~/bin/lg-sync 2>/dev/null || ~/scripts/lg-sync 2>/dev/null || echo 'sync not found'"

    /** Clears all KML references — blanks every browser in the cluster. */
    val blankCmd = "echo '' > /var/www/html/kmls.txt"

    /** Escapes single-quotes so the password is safe inside a single-quoted shell string. */
    private fun shellEscape(s: String) = s.replace("'", "'\\''")
}
