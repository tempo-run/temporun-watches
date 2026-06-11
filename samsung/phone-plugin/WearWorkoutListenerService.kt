package com.temporun.run.wear

import android.util.Log
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * LADO CELULAR (integrar no temporun-app/android). Equivalente Android do
 * PhoneSessionManager.swift. Recebe a corrida do relógio pelo Wearable Data Layer e a grava
 * chamando a edge function watch-workout-save — SEM depender do WebView/JS estar aberto
 * (decisão D1, samsung/DECISIONS.md).
 *
 * Caminhos (devem casar com DataLayerManager.kt do relógio):
 *   /temporun/workout      → DataClient (entrega garantida) → POST na edge function
 *   /temporun/live-update  → MessageClient (efêmero) → repassa ao JS via broadcast (opcional)
 *
 * Credenciais: gravadas em SharedPreferences por [WearBridgePlugin.setCredentials], chamado
 * pelo JS no login (espelha CredentialSyncToWatch.swift).
 */
class WearWorkoutListenerService : WearableListenerService() {

    private val prefs by lazy { getSharedPreferences("temporun_wear", MODE_PRIVATE) }

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val item = event.dataItem
            if (item.uri.path != PATH_WORKOUT) continue

            val map = DataMapItem.fromDataItem(item).dataMap
            val body = map.getString(KEY_BODY) ?: continue
            saveCorrida(body)

            // Limpa o DataItem após consumir, para não acumular no Data Layer.
            runCatching { dataClient.deleteDataItems(item.uri) }
        }
    }

    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != PATH_LIVE_UPDATE) return
        // Opcional (Fase 2.1): repassar ao JS via LocalBroadcast/Capacitor event para a UI
        // de "corrida em andamento no relógio". Não persiste nada.
    }

    private fun saveCorrida(body: String) {
        val url = prefs.getString("supabaseUrl", null)
        val anonKey = prefs.getString("supabaseAnonKey", null)
        val token = prefs.getString("supabaseAccessToken", null)
        if (url.isNullOrEmpty() || anonKey.isNullOrEmpty() || token.isNullOrEmpty()) {
            Log.w(TAG, "Credenciais Supabase ausentes — corrida do relógio não enviada.")
            // TODO(Fase 5): enfileirar localmente e reenviar quando o usuário logar.
            return
        }

        Thread {
            runCatching {
                val conn = (URL("$url/functions/v1/watch-workout-save").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    doOutput = true
                    connectTimeout = 15000
                    readTimeout = 30000
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("apikey", anonKey)
                    setRequestProperty("Authorization", "Bearer $token")
                }
                conn.outputStream.use { os: OutputStream -> os.write(body.toByteArray()) }
                val code = conn.responseCode
                if (code !in 200..299) {
                    val err = conn.errorStream?.bufferedReader()?.readText().orEmpty()
                    Log.e(TAG, "watch-workout-save HTTP $code: $err")
                    // TODO(Fase 5): refresh de token no 401 + fila de retry.
                } else {
                    val resp = conn.inputStream.bufferedReader().readText()
                    val json = JSONObject(resp)
                    Log.i(TAG, "Corrida do relógio salva: id=${json.optString("corrida_id")} " +
                            "xp=${json.optInt("xp_ganho")} streak=${json.optInt("streak_atual")}")
                    // TODO: emitir evento para o JS (XP/streak/recordes) p/ a UI reagir.
                }
            }.onFailure { Log.e(TAG, "Falha ao salvar corrida do relógio", it) }
        }.start()
    }

    companion object {
        private const val TAG = "WearWorkout"
        private const val PATH_WORKOUT = "/temporun/workout"
        private const val PATH_LIVE_UPDATE = "/temporun/live-update"
        private const val KEY_BODY = "body"
    }
}
