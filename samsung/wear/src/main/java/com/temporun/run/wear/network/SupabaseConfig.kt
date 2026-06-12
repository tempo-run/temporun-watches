package com.temporun.run.wear.network

import android.content.Context

/**
 * Credenciais Supabase do modo standalone, recebidas do celular via Data Layer e guardadas em
 * SharedPreferences. Espelha SupabaseConfig.swift (que usava o App Group). No Wear não há App
 * Group — cada dispositivo tem seu armazenamento, e a sincronização é só via Data Layer.
 */
object SupabaseConfig {
    private const val PREFS = "temporun_wear"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun url(context: Context) = prefs(context).getString("supabaseUrl", "").orEmpty()
    fun anonKey(context: Context) = prefs(context).getString("supabaseAnonKey", "").orEmpty()
    fun accessToken(context: Context) = prefs(context).getString("supabaseAccessToken", "").orEmpty()
    fun refreshToken(context: Context) = prefs(context).getString("supabaseRefreshToken", "").orEmpty()
    fun userId(context: Context) = prefs(context).getString("supabaseUserId", "").orEmpty()

    fun isConfigured(context: Context): Boolean =
        url(context).isNotEmpty() && anonKey(context).isNotEmpty() &&
            accessToken(context).isNotEmpty() && userId(context).isNotEmpty()

    /** Recebe credenciais do celular (payload do Data Layer). NSNull/ausência = logout → limpa. */
    fun apply(context: Context, creds: Map<String, String?>) {
        val e = prefs(context).edit()
        if (creds["url"].isNullOrEmpty()) {
            listOf("supabaseUrl", "supabaseAnonKey", "supabaseAccessToken", "supabaseRefreshToken", "supabaseUserId")
                .forEach { e.remove(it) }
        } else {
            e.putString("supabaseUrl", creds["url"])
            e.putString("supabaseAnonKey", creds["anonKey"])
            e.putString("supabaseAccessToken", creds["accessToken"])
            e.putString("supabaseRefreshToken", creds["refreshToken"])
            e.putString("supabaseUserId", creds["userId"])
        }
        e.apply()
    }

    fun saveTokens(context: Context, accessToken: String, refreshToken: String) {
        prefs(context).edit()
            .putString("supabaseAccessToken", accessToken)
            .putString("supabaseRefreshToken", refreshToken)
            .apply()
    }
}
