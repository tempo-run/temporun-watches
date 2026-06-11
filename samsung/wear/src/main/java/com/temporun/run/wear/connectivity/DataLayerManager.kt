package com.temporun.run.wear.connectivity

import android.content.Context
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * Comunicação com o celular pelo Wearable Data Layer. Equivalente ao WatchSessionManager.swift
 * (WatchConnectivity). Ver WEAR_OS_PLAN.md §6 e DECISIONS.md (D1).
 *
 * Dois canais, espelhando o Apple:
 * - **Corrida final** (`/temporun/workout`): `DataClient` com `setUrgent()` — entrega
 *   GARANTIDA, sobrevive a desconexão e à morte do app (análogo ao `transferUserInfo`).
 *   O corpo já é o JSON do contrato (`toSupabaseMap().toJsonString()`); o celular só repassa
 *   para a edge function watch-workout-save.
 * - **Atualização ao vivo** (`/temporun/live-update`): `MessageClient.sendMessage` — imediato
 *   e efêmero, best-effort, só quando há nó conectado (análogo ao `updateApplicationContext`).
 */
class DataLayerManager(context: Context) {

    private val appContext = context.applicationContext
    private val dataClient by lazy { Wearable.getDataClient(appContext) }
    private val messageClient by lazy { Wearable.getMessageClient(appContext) }
    private val nodeClient by lazy { Wearable.getNodeClient(appContext) }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        const val PATH_WORKOUT = "/temporun/workout"
        const val PATH_LIVE_UPDATE = "/temporun/live-update"
        const val KEY_BODY = "body"          // JSON do contrato (corpo do POST no celular)
        const val KEY_DEDUP = "key"          // unicidade da corrida (data_inicio ISO)
    }

    /** Envia a corrida encerrada com entrega garantida. */
    fun sendWorkout(payload: WorkoutPayload) {
        val body = payload.toSupabaseMap().toJsonString()
        scope.launch {
            runCatching {
                val req = PutDataMapRequest.create(PATH_WORKOUT).apply {
                    dataMap.putString(KEY_BODY, body)
                    dataMap.putString(KEY_DEDUP, payload.startDateIso)
                }.asPutDataRequest().setUrgent()
                dataClient.putDataItem(req).await()
            }
        }
    }

    /** Envia métricas ao vivo (pace/FC/distância) — best-effort, só se há nó conectado. */
    fun sendLiveUpdate(distanceKm: Double, paceSec: Double, heartRate: Double, elapsedSec: Long) {
        val bytes = LiveUpdate(distanceKm, paceSec, heartRate, elapsedSec).toBytes()
        scope.launch {
            runCatching {
                val nodes = nodeClient.connectedNodes.await()
                nodes.forEach { node ->
                    runCatching { messageClient.sendMessage(node.id, PATH_LIVE_UPDATE, bytes).await() }
                }
            }
        }
    }
}
