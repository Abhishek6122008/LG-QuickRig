package com.liqtech.lg_quickrig.lg

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

data class LGCredentials(
    val host: String,
    val port: Int,
    val username: String,
    val password: String,
    val nodeCount: Int,
)

object LGCredentialStore {

    private const val PREFS_NAME = "LGQuickRigWidgetCreds"

    private const val KEY_HOST       = "lg_cred_host"
    private const val KEY_PORT       = "lg_cred_port"
    private const val KEY_USERNAME   = "lg_cred_username"
    private const val KEY_PASSWORD   = "lg_cred_password"
    private const val KEY_NODE_COUNT = "lg_cred_node_count"

    private fun prefs(context: Context): android.content.SharedPreferences {
        val masterKey = MasterKey.Builder(context, MasterKey.DEFAULT_MASTER_KEY_ALIAS)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    fun save(
        context: Context,
        host: String,
        port: Int,
        username: String,
        password: String,
        nodeCount: Int,
    ) {
        try {
            prefs(context).edit()
                .putString(KEY_HOST, host)
                .putString(KEY_PORT, port.toString())
                .putString(KEY_USERNAME, username)
                .putString(KEY_PASSWORD, password)
                .putString(KEY_NODE_COUNT, nodeCount.toString())
                .apply()
        } catch (e: Exception) {
        }
    }

    fun clear(context: Context) {
        try {
            prefs(context).edit().clear().apply()
        } catch (e: Exception) {
        }
    }

    fun load(context: Context): LGCredentials? {
        return try {
            val p = prefs(context)
            val host = p.getString(KEY_HOST, null)
            if (host.isNullOrEmpty()) return null

            LGCredentials(
                host      = host,
                port      = p.getString(KEY_PORT, "22")?.toIntOrNull() ?: 22,
                username  = p.getString(KEY_USERNAME, "lg") ?: "lg",
                password  = p.getString(KEY_PASSWORD, "") ?: "",
                nodeCount = p.getString(KEY_NODE_COUNT, "3")?.toIntOrNull() ?: 3,
            )
        } catch (e: Exception) {
            null
        }
    }

    fun hasCredentials(context: Context): Boolean = load(context) != null
}
