package com.liqtech.lg_quickrig.lg

import com.jcraft.jsch.ChannelExec
import com.jcraft.jsch.JSch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object LGSshExecutor {

    private const val CONNECT_TIMEOUT_MS = 10_000

    // Reboot/shutdown fan out to every slave with a 5s connect timeout each,
    // so the budget must cover an unreachable rig, not a single command.
    private const val EXEC_TIMEOUT_MS   = 30_000

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

    // The Quick Settings tile pings on every shade pull and the status widget
    // every 5 minutes, each costing a full SSH handshake. Pulling the shade
    // twice in a row should not dial the rig twice.
    private const val PING_CACHE_MS = 30_000L

    private var lastPingHost: String? = null
    private var lastPingResult = false
    private var lastPingAt = 0L

    suspend fun ping(creds: LGCredentials): Boolean = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        synchronized(this@LGSshExecutor) {
            if (creds.host == lastPingHost && now - lastPingAt < PING_CACHE_MS) {
                return@withContext lastPingResult
            }
        }

        val reachable = runCatching {
            val jsch    = JSch()
            val session = jsch.getSession(creds.username, creds.host, creds.port)
            session.setPassword(creds.password)
            session.setConfig("StrictHostKeyChecking", "no")
            session.timeout = 8_000
            session.connect()
            session.disconnect()
        }.isSuccess

        synchronized(this@LGSshExecutor) {
            lastPingHost = creds.host
            lastPingResult = reachable
            lastPingAt = System.currentTimeMillis()
        }
        reachable
    }

    /**
     * Drops the cached result so the next ping dials for real. Used when the
     * user explicitly asks for a refresh — a tap that answered from cache
     * would look like the button did nothing.
     */
    fun invalidatePingCache() = synchronized(this) { lastPingAt = 0L }

    fun rebootCmd(password: String, nodeCount: Int) =
        fanOutSudoCmd("sudo -S reboot", password, nodeCount)

    fun shutdownCmd(password: String, nodeCount: Int) =
        fanOutSudoCmd("sudo -S shutdown -h now", password, nodeCount)

    /**
     * Runs `echo 'password' | sudoCmd` on every slave (lgN..lg2, hopping
     * through the master with sshpass) and finally on the master itself —
     * mirrors LGCommandService.reboot/shutdown on the Dart side.
     */
    private fun fanOutSudoCmd(sudoCmd: String, password: String, nodeCount: Int): String {
        val p = shellEscape(password)
        val remote = "echo '$p' | $sudoCmd"
        val sb = StringBuilder()
        for (i in nodeCount downTo 2) {
            sb.append(
                "sshpass -p '$p' ssh -t -o StrictHostKeyChecking=no -o ConnectTimeout=5 " +
                "lg@lg$i '${remote.replace("'", "'\\''")}' 2>/dev/null; "
            )
        }
        sb.append(remote)
        return sb.toString()
    }

    val syncCmd =
        "~/scripts/lg-sync 2>/dev/null || ~/bin/lg-sync 2>/dev/null || echo 'sync not found'"

    // ponytail: blanks the master playlist only; the app's Blank Screens
    // also clears each slave_N.kml — add the fan-out here if anyone notices.
    val blankCmd = "echo '' > /var/www/html/kmls.txt"

    val cleanCmd =
        "rm -f /var/www/html/kml/lgquickrig_*.kml 2>/dev/null; " +
        "sed -i '/lgquickrig/d' /var/www/html/kmls.txt 2>/dev/null; echo 'cleaned'"

    val relaunchCmd =
        "export DISPLAY=:0; pkill -9 chrome 2>/dev/null; sleep 1; " +
        "/home/lg/bin/lg-relaunch 2>/dev/null || ~/scripts/lg-relaunch 2>/dev/null || echo 'relaunch not found'"

    private fun shellEscape(s: String) = s.replace("'", "'\\''")
}
