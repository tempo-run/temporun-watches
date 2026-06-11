package com.temporun.run.wear.connectivity

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import com.temporun.run.wear.training.TrainingPlanRepository

/**
 * LADO RELÓGIO — recebe dados enviados pelo celular via Data Layer. Contraparte do
 * WearWorkoutListenerService do celular (que recebe a corrida no sentido oposto).
 *
 * Fase 3: plano de treino (`/temporun/plan`).
 * TODO(Fase 4): dados de complicação (`/temporun/complication`).
 * TODO(Fase 5): credenciais Supabase (`/temporun/credentials`) para o modo standalone.
 *
 * IMPORTANTE: `onDataChanged` também dispara para itens que ESTE nó criou (ex.: a corrida em
 * `/temporun/workout`). Por isso filtramos pelo path exato `/temporun/plan`.
 */
class WearListenerService : WearableListenerService() {

    override fun onDataChanged(events: DataEventBuffer) {
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            if (event.dataItem.uri.path != PATH_PLAN) continue
            val map = DataMapItem.fromDataItem(event.dataItem).dataMap
            val planJson = map.getString(KEY_PLAN) ?: continue
            TrainingPlanRepository.ensureInit(applicationContext)
            TrainingPlanRepository.applyJson(planJson)
        }
    }

    companion object {
        const val PATH_PLAN = "/temporun/plan"
        const val KEY_PLAN = "plan"
    }
}
