package com.temporun.run.wear.connectivity

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import com.temporun.run.wear.complications.ComplicationStore
import com.temporun.run.wear.network.OfflineQueue
import com.temporun.run.wear.network.SupabaseConfig
import com.temporun.run.wear.training.TrainingPlanRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * LADO RELÓGIO — recebe dados enviados pelo celular via Data Layer. Contraparte do
 * WearWorkoutListenerService do celular (que recebe a corrida no sentido oposto).
 *
 * - `/temporun/plan` (Fase 3): plano de treino.
 * - `/temporun/credentials` (Fase 5): credenciais Supabase p/ o modo standalone.
 * - `/temporun/complication` (Fase 4): dados de glanceability (km/streak/próximo treino).
 *
 * IMPORTANTE: `onDataChanged` também dispara para itens que ESTE nó criou (ex.: a corrida em
 * `/temporun/workout`). Por isso filtramos pelo path exato.
 */
class WearListenerService : WearableListenerService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val map = DataMapItem.fromDataItem(event.dataItem).dataMap
            when (event.dataItem.uri.path) {
                PATH_PLAN -> map.getString(KEY_PLAN)?.let { planJson ->
                    TrainingPlanRepository.ensureInit(applicationContext)
                    TrainingPlanRepository.applyJson(planJson)
                }
                PATH_CREDENTIALS -> {
                    val creds = mapOf(
                        "url" to map.getString("url"),
                        "anonKey" to map.getString("anonKey"),
                        "accessToken" to map.getString("accessToken"),
                        "refreshToken" to map.getString("refreshToken"),
                        "userId" to map.getString("userId"),
                    )
                    SupabaseConfig.apply(applicationContext, creds)
                    OfflineQueue.ensureInit(applicationContext)
                    scope.launch { OfflineQueue.syncAll() } // flush imediato se há fila pendente
                }
                PATH_COMPLICATION -> map.getString(KEY_COMPLICATION)?.let { json ->
                    ComplicationStore.apply(applicationContext, json) // persiste + refresca tile/complication
                }
            }
        }
    }

    companion object {
        const val PATH_PLAN = "/temporun/plan"
        const val PATH_CREDENTIALS = "/temporun/credentials"
        const val PATH_COMPLICATION = "/temporun/complication"
        const val KEY_PLAN = "plan"
        const val KEY_COMPLICATION = "data"
    }
}
