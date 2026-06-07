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

    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        val creds = LGCredentialStore.load(this)

        if (creds == null) {
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

        refreshTile()
    }

    private fun refreshTile() {
        pingJob?.cancel()

        val creds = LGCredentialStore.load(this)
        if (creds == null) {
            setTileState(Tile.STATE_INACTIVE, "Not configured")
            return
        }

        setTileState(Tile.STATE_UNAVAILABLE, "Checking...")

        pingJob = scope.launch {
            val reachable = LGSshExecutor.ping(creds)
            val (state, subtitle) = if (reachable)
                Tile.STATE_ACTIVE   to "Connected - ${creds.host}"
            else
                Tile.STATE_INACTIVE to "Unreachable - ${creds.host}"

            android.os.Handler(android.os.Looper.getMainLooper()).post {
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
