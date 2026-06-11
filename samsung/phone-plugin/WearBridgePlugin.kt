package com.temporun.run.wear

import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

/**
 * LADO CELULAR (integrar no temporun-app/android). Ponte Capacitor mínima entre o JS do
 * temporun-app e o lado nativo do Wearable Data Layer.
 *
 * Responsabilidade nesta fase: o JS repassa as credenciais Supabase (após login) para o nativo,
 * que as guarda em SharedPreferences — de onde o [WearWorkoutListenerService] as lê para chamar
 * a edge function mesmo com o app fechado. Espelha CredentialSyncToWatch.swift.
 *
 * Uso no JS (temporun-app), após login/refresh de sessão:
 *   import { registerPlugin } from '@capacitor/core'
 *   const Wear = registerPlugin('WearBridge')
 *   await Wear.setCredentials({ url, anonKey, accessToken, refreshToken, userId })
 *   // no logout:
 *   await Wear.clearCredentials()
 *
 * TODO(Fase 3): syncPlan(plano) — envia o plano ativo ao relógio via DataClient.
 * TODO(Fase 4): syncComplication(data) — envia km/streak/xp/próximo treino.
 */
@CapacitorPlugin(name = "WearBridge")
class WearBridgePlugin : Plugin() {

    private val prefs by lazy { context.getSharedPreferences("temporun_wear", android.content.Context.MODE_PRIVATE) }

    @PluginMethod
    fun setCredentials(call: PluginCall) {
        prefs.edit().apply {
            putString("supabaseUrl", call.getString("url"))
            putString("supabaseAnonKey", call.getString("anonKey"))
            putString("supabaseAccessToken", call.getString("accessToken"))
            putString("supabaseRefreshToken", call.getString("refreshToken"))
            putString("supabaseUserId", call.getString("userId"))
            apply()
        }
        // Também envia ao relógio (modo standalone — Fase 5). Mantém o app local resolvendo logo.
        val req = PutDataMapRequest.create("/temporun/credentials").apply {
            dataMap.putString("url", call.getString("url"))
            dataMap.putString("anonKey", call.getString("anonKey"))
            dataMap.putString("accessToken", call.getString("accessToken"))
            dataMap.putString("refreshToken", call.getString("refreshToken"))
            dataMap.putString("userId", call.getString("userId"))
            dataMap.putLong("ts", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(req)
        call.resolve()
    }

    @PluginMethod
    fun clearCredentials(call: PluginCall) {
        prefs.edit().clear().apply()
        // Limpa também no relógio (logout): envia credenciais vazias → SupabaseConfig.apply limpa.
        val req = PutDataMapRequest.create("/temporun/credentials").apply {
            dataMap.putString("url", "")
            dataMap.putLong("ts", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(req)
        call.resolve()
    }

    /**
     * Envia o plano de treino ativo ao relógio via Data Layer (`/temporun/plan`).
     * O JS passa `{ plan: <row de planos_treino em JSON string> }`. O relógio recebe em
     * WearListenerService e o aplica em TrainingPlanRepository. Espelha PlanSyncToWatch.swift.
     */
    @PluginMethod
    fun syncPlan(call: PluginCall) {
        val planJson = call.getString("plan")
        if (planJson.isNullOrEmpty()) {
            call.reject("plan ausente")
            return
        }
        val req = PutDataMapRequest.create("/temporun/plan").apply {
            dataMap.putString("plan", planJson)
            dataMap.putLong("ts", System.currentTimeMillis()) // força atualização do DataItem
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(req)
            .addOnSuccessListener { call.resolve() }
            .addOnFailureListener { call.reject(it.message ?: "falha ao enviar plano") }
    }

    /**
     * Envia os dados de glanceability (complications + tile) ao relógio (Fase 4).
     * O JS passa `{ data: JSON.stringify({ weeklyKm, weeklyGoalKm, streakDays, xp,
     * nextWorkoutType, nextWorkoutKm, nextWorkoutDay }) }`. Espelha ComplicationSyncToWatch.swift.
     */
    @PluginMethod
    fun syncComplication(call: PluginCall) {
        val data = call.getString("data")
        if (data.isNullOrEmpty()) {
            call.reject("data ausente")
            return
        }
        val req = PutDataMapRequest.create("/temporun/complication").apply {
            dataMap.putString("data", data)
            dataMap.putLong("ts", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(req)
            .addOnSuccessListener { call.resolve() }
            .addOnFailureListener { call.reject(it.message ?: "falha ao enviar complication") }
    }
}
