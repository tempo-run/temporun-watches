package com.temporun.run.wear

import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin

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
        call.resolve()
    }

    @PluginMethod
    fun clearCredentials(call: PluginCall) {
        prefs.edit().clear().apply()
        call.resolve()
    }
}
