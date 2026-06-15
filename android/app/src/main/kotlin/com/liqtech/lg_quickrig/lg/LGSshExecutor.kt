package com.liqtech.lg_quickrig.lg

import com.jcraft.jsch.ChannelExec
import com.jcraft.jsch.JSch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object LGSshExecutor {

    private const val CONNECT_TIMEOUT_MS = 10_000
    private const val EXEC_TIMEOUT_MS   = 15_000

    suspend fun execute(
        creds: LGCredentials,
        command: String,
        timeoutMs: Int = EXEC_TIMEOUT_MS,
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val jsch    = JSch()
            val session = jsch.getSession(creds.username, creds.host, creds.port)
            session.setPassword(creds.password)
            session.setConfig("StrictHostKeyChecking", "no")
            session.timeout = CONNECT_TIMEOUT_MS
            session.connect()

            val channel = session.openChannel("exec") as ChannelExec
            channel.setCommand(command)

            val stdout = channel.inputStream
            val stderr = channel.errStream
            channel.connect()

            val deadline = System.currentTimeMillis() + timeoutMs
            while (!channel.isClosed && System.currentTimeMillis() < deadline) {
                Thread.sleep(50)
            }

            val out = stdout.bufferedReader().readText().trim()
            val err = stderr.bufferedReader().readText().trim()

            channel.disconnect()
            session.disconnect()

            when {
                out.isNotEmpty() -> out
                err.isNotEmpty() -> "[stderr] $err"
                else             -> ""
            }
        }
    }

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

    fun rebootCmd(password: String) =
        "echo '${shellEscape(password)}' | sudo -S reboot"

    fun shutdownCmd(password: String) =
        "echo '${shellEscape(password)}' | sudo -S shutdown -h now"

    val syncCmd =
        "~/bin/lg-sync 2>/dev/null || ~/scripts/lg-sync 2>/dev/null || echo 'sync not found'"

    val blankCmd = "echo '' > /var/www/html/kmls.txt"

    val cleanCmd =
        "rm -f /var/www/html/kml/lgquickrig_*.kml 2>/dev/null; " +
        "sed -i '/lgquickrig/d' /var/www/html/kmls.txt 2>/dev/null; echo 'cleaned'"

    val relaunchCmd =
        "export DISPLAY=:0; pkill -9 chrome 2>/dev/null; sleep 1; " +
        "/home/lg/bin/lg-relaunch 2>/dev/null || ~/scripts/lg-relaunch 2>/dev/null || echo 'relaunch not found'"

    private fun shellEscape(s: String) = s.replace("'", "'\\''")
}
