package com.liqtech.lg_quickrig.lg

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import com.liqtech.lg_quickrig.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@RequiresApi(Build.VERSION_CODES.N)
class LGQuickSettingsTile : TileService() {

    private val scope = CoroutineScope(Dispatchers.IO)
    private var pingJob: Job? = null

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onStopListening() {
        super.onStopListening()
        pingJob?.cancel()
    }

    /** Tapping the tile opens the app — predictable, and the panel shows
     *  live status via the subtitle anyway. */
    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        val launchIntent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(
                    this, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(launchIntent)
        }
    }

    private fun refreshTile() {
        pingJob?.cancel()

        // Keep the tile INACTIVE (not UNAVAILABLE) while checking — an
        // unavailable tile is untappable and can wedge there if a ping hangs.
        setTileState(Tile.STATE_INACTIVE, "Checking…")

        pingJob = scope.launch {
            // EncryptedSharedPreferences init is too slow for the main thread.
            val creds = LGCredentialStore.load(this@LGQuickSettingsTile)
            if (creds == null) {
                withContext(Dispatchers.Main) {
                    setTileState(Tile.STATE_INACTIVE, "Not configured")
                }
                return@launch
            }

            val reachable = LGSshExecutor.ping(creds)
            val (state, subtitle) = if (reachable)
                Tile.STATE_ACTIVE   to "Connected - ${creds.host}"
            else
                Tile.STATE_INACTIVE to "Unreachable - ${creds.host}"

            withContext(Dispatchers.Main) {
                setTileState(state, subtitle)
            }
        }
    }

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
