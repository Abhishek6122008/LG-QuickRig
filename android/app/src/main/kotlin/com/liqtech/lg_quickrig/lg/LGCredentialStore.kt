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

    private const val PREFS_NAME = "FlutterSecureStorage"

    private const val KEY_HOST       = "lg_cred_host"
    private const val KEY_PORT       = "lg_cred_port"
    private const val KEY_USERNAME   = "lg_cred_username"
    private const val KEY_PASSWORD   = "lg_cred_password"
    private const val KEY_NODE_COUNT = "lg_cred_node_count"

    fun load(context: Context): LGCredentials? {
        return try {
            val masterKey = MasterKey.Builder(context, MasterKey.DEFAULT_MASTER_KEY_ALIAS)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val prefs = EncryptedSharedPreferences.create(
                context,
                PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            )

            val host = prefs.getString(KEY_HOST, null)
            if (host.isNullOrEmpty()) return null

            LGCredentials(
                host      = host,
                port      = prefs.getString(KEY_PORT, "22")?.toIntOrNull() ?: 22,
                username  = prefs.getString(KEY_USERNAME, "lg") ?: "lg",
                password  = prefs.getString(KEY_PASSWORD, "") ?: "",
                nodeCount = prefs.getString(KEY_NODE_COUNT, "3")?.toIntOrNull() ?: 3,
            )
        } catch (e: Exception) {
            null
        }
    }

    fun hasCredentials(context: Context): Boolean = load(context) != null
}
