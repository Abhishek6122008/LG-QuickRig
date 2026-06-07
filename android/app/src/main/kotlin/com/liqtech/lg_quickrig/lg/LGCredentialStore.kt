package com.liqtech.lg_quickrig.lg

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Reads LG SSH credentials from the platform secure store.
 *
 * flutter_secure_storage (with encryptedSharedPreferences = true) writes to an
 * EncryptedSharedPreferences file named "FlutterSecureStorage", using the default
 * AndroidX MasterKey alias. Opening the same file with the same key from Kotlin
 * gives us direct, zero-copy read access to whatever the Dart Settings screen saved.
 *
 * Key names must stay in sync with CredentialsRepository in Dart:
 *   lg_cred_host, lg_cred_port, lg_cred_username, lg_cred_password, lg_cred_node_count
 */
data class LGCredentials(
    val host: String,
    val port: Int,
    val username: String,
    val password: String,
    val nodeCount: Int,
)

object LGCredentialStore {

    // Must match the SharedPreferences name used by flutter_secure_storage internally.
    private const val PREFS_NAME = "FlutterSecureStorage"

    // Must match the static key constants in lib/data/repositories/credentials_repository.dart.
    private const val KEY_HOST       = "lg_cred_host"
    private const val KEY_PORT       = "lg_cred_port"
    private const val KEY_USERNAME   = "lg_cred_username"
    private const val KEY_PASSWORD   = "lg_cred_password"
    private const val KEY_NODE_COUNT = "lg_cred_node_count"

    /**
     * Returns saved credentials, or null if none have been configured yet.
     *
     * This call is synchronous and cheap (in-process Keystore read); it is safe to
     * call from a background coroutine but never from the main thread in production.
     */
    fun load(context: Context): LGCredentials? {
        return try {
            // Rebuild the same MasterKey that flutter_secure_storage created on first write.
            // The Android Keystore returns the existing key if the alias already exists,
            // so this is guaranteed to be the same key.
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
            if (host.isNullOrEmpty()) return null   // no credentials saved yet

            LGCredentials(
                host      = host,
                port      = prefs.getString(KEY_PORT, "22")?.toIntOrNull() ?: 22,
                username  = prefs.getString(KEY_USERNAME, "lg") ?: "lg",
                password  = prefs.getString(KEY_PASSWORD, "") ?: "",
                nodeCount = prefs.getString(KEY_NODE_COUNT, "3")?.toIntOrNull() ?: 3,
            )
        } catch (e: Exception) {
            // EncryptedSharedPreferences can throw if the Keystore is in a bad state
            // (e.g., after a factory reset on some OEMs). Treat as unconfigured.
            null
        }
    }

    /** Returns true if at least a host has been saved. */
    fun hasCredentials(context: Context): Boolean = load(context) != null
}
