package com.temporun.run.wear.network

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.net.HttpURLConnection
import java.net.URL

/** Resultado da edge function watch-workout-save. */
data class SaveOutcome(val ok: Boolean, val httpCode: Int, val body: String)

/**
 * Cliente do modo standalone (relógio com rede própria → Supabase direto). Equivalente ao
 * SupabaseClient.swift. Bate na MESMA edge function watch-workout-save (DECISIONS.md D1).
 *
 * Usa HttpURLConnection (sem dependência extra; o lado Apple também usa o cliente da
 * plataforma, URLSession). source = "wear_os_standalone".
 */
object SupabaseClient {

    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Envia o corpo (JSON do contrato) para a edge function. Em 401, tenta refresh de token uma
     * vez e repete. Retorna o resultado para a UI/fila decidirem.
     */
    suspend fun insertCorrida(context: Context, body: String): SaveOutcome = withContext(Dispatchers.IO) {
        if (!SupabaseConfig.isConfigured(context)) return@withContext SaveOutcome(false, 0, "not_configured")

        var outcome = post(context, body)
        if (outcome.httpCode == 401 && refreshToken(context)) {
            outcome = post(context, body)
        }
        outcome
    }

    private fun post(context: Context, body: String): SaveOutcome {
        val base = SupabaseConfig.url(context)
        val conn = (URL("$base/functions/v1/watch-workout-save-samsung").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 15000
            readTimeout = 30000
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("apikey", SupabaseConfig.anonKey(context))
            setRequestProperty("Authorization", "Bearer ${SupabaseConfig.accessToken(context)}")
        }
        return try {
            conn.outputStream.use { it.write(body.toByteArray()) }
            val code = conn.responseCode
            val text = (if (code in 200..299) conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use { r -> r.readText() }.orEmpty()
            SaveOutcome(code in 200..299, code, text)
        } catch (e: Exception) {
            SaveOutcome(false, -1, e.message ?: "network_error")
        } finally {
            conn.disconnect()
        }
    }

    /** Refresh do access token via /auth/v1/token. Persiste os novos tokens. */
    private fun refreshToken(context: Context): Boolean {
        val refresh = SupabaseConfig.refreshToken(context)
        if (refresh.isEmpty()) return false
        val base = SupabaseConfig.url(context)
        val conn = (URL("$base/auth/v1/token?grant_type=refresh_token").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 15000
            readTimeout = 15000
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("apikey", SupabaseConfig.anonKey(context))
        }
        return try {
            conn.outputStream.use { it.write("""{"refresh_token":"$refresh"}""".toByteArray()) }
            if (conn.responseCode !in 200..299) return false
            val obj = json.parseToJsonElement(conn.inputStream.bufferedReader().use { it.readText() }) as? JsonObject
            val access = (obj?.get("access_token") as? JsonPrimitive)?.content
            val newRefresh = (obj?.get("refresh_token") as? JsonPrimitive)?.content
            if (access != null && newRefresh != null) {
                SupabaseConfig.saveTokens(context, access, newRefresh)
                true
            } else false
        } catch (e: Exception) {
            false
        } finally {
            conn.disconnect()
        }
    }
}
