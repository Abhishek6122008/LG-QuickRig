package com.liqtech.lg_quickrig.lg

import android.annotation.SuppressLint
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Quick Settings tile for the LG QuickRig connect/disconnect toggle.
 *
 * Appears in the Android system shade (notification + quick-settings panel).
 * Requires API 24+ (Android 7.0 Nougat). On API 23 the manifest entry is
 * present but the system ignores it — no crash, just no tile.
 *
 * ── TileService lifecycle ─────────────────────────────────────────────────────
 *
 *   onStartListening()  — tile is visible; update state now and again on change.
 *   onStopListening()   — tile is no longer visible; cancel pending work.
 *   onClick()           — user tapped the tile; run the primary action.
 *
 * The tile has three visual states:
 *   STATE_ACTIVE    → teal icon, indicates the LG node is reachable
 *   STATE_INACTIVE  → grey icon, no live connection / credentials not set
 *   STATE_UNAVAILABLE → dimmed, used during the SSH ping while connecting
 *
 * ── What "connect" means here ────────────────────────────────────────────────
 * TileService runs in a bound-service context — there is no shared SSH socket
 * with the Flutter engine. "Active" means the saved credentials pass an SSH
 * handshake check (ping). The tile does not hold an open connection between taps.
 * ─────────────────────────────────────────────────────────────────────────────
 */
@RequiresApi(Build.VERSION_CODES.N)
class LGQuickSettingsTile : TileService() {

    private val scope = CoroutineScope(Dispatchers.IO)
    private var pingJob: Job? = null

    // ── TileService callbacks ─────────────────────────────────────────────────

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onStopListening() {
        super.onStopListening()
        pingJob?.cancel()
    }

    /**
     * Called when the user taps the tile.
     *
     * If credentials are not configured, launch the main app's Settings screen.
     * If configured and reachable → no action (already connected / stateless).
     * If configured but last ping failed → re-run the ping to check again.
     */
    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        val creds = LGCredentialStore.load(this)

        if (creds == null) {
            // No credentials — open the app so the user can configure them.
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startActivityAndCollapse(
                        android.app.PendingIntent.getActivity(
                            this, 0, launchIntent,
                            android.app.PendingIntent.FLAG_IMMUTABLE,
                        )
                    )
                } else {
                    @Suppress("DEPRECATION")
                    startActivityAndCollapse(launchIntent)
                }
            }
            return
        }

        // Credentials exist — re-ping to refresh the tile state.
        refreshTile()
    }

    // ── Internal helpers ──────────────────────────────────────────────────────

    /**
     * Pings the LG node on a background coroutine and updates the tile state.
     *
     * Sets STATE_UNAVAILABLE (spinner) while the ping is in flight, then
     * transitions to STATE_ACTIVE or STATE_INACTIVE based on the result.
     */
    private fun refreshTile() {
        pingJob?.cancel()

        val creds = LGCredentialStore.load(this)
        if (creds == null) {
            setTileState(Tile.STATE_INACTIVE, "Not configured")
            return
        }

        setTileState(Tile.STATE_UNAVAILABLE, "Checking…")

        pingJob = scope.launch {
            val reachable = LGSshExecutor.ping(creds)
            val (state, subtitle) = if (reachable)
                Tile.STATE_ACTIVE   to "Connected — ${creds.host}"
            else
                Tile.STATE_INACTIVE to "Unreachable — ${creds.host}"

            // TileService methods that touch the tile must run on the main thread.
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                setTileState(state, subtitle)
            }
        }
    }

    /** Applies [state] and [subtitle] to the tile and calls [updateTile]. */
    private fun setTileState(state: Int, subtitle: String) {
        qsTile?.apply {
            this.state = state
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                this.subtitle = subtitle
            }
            updateTile()
        }
    }
}
