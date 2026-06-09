package com.temporun.run.wear.connectivity

import android.content.Context
import com.google.android.gms.wearable.Wearable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Comunicação com o celular pelo Wearable Data Layer. Equivalente ao WatchSessionManager.swift
 * (WatchConnectivity). Ver WEAR_OS_PLAN.md §6 e DECISIONS.md (D1).
 *
 * Fase 0: esqueleto com os clientes do Data Layer.
 * TODO(Fase 2): enviar WorkoutPayload via DataClient.putDataItem(...).setUrgent() (entrega
 *               garantida) + MessageClient.sendMessage (imediato) e live update a cada 5s.
 *               O celular (plugin Capacitor) recebe e chama a edge function watch-workout-save.
 */
class DataLayerManager(context: Context) {

    private val appContext = context.applicationContext
    private val messageClient by lazy { Wearable.getMessageClient(appContext) }
    private val dataClient by lazy { Wearable.getDataClient(appContext) }
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }

    companion object {
        const val PATH_WORKOUT = "/temporun/workout"
        const val PATH_LIVE_UPDATE = "/temporun/live-update"
        const val PATH_REQUEST_PLAN = "/temporun/request-plan"
    }

    /** Serializa a corrida para envio. Implementação de transporte vem na Fase 2. */
    fun encodeWorkout(payload: WorkoutPayload): String = json.encodeToString(payload)

    fun sendWorkout(payload: WorkoutPayload) {
        // TODO(Fase 2): dataClient.putDataItem(...).setUrgent() + fallback MessageClient
    }

    fun sendLiveUpdate(distanceKm: Double, paceSec: Double, heartRate: Double, elapsedSec: Long) {
        // TODO(Fase 2): messageClient.sendMessage(node, PATH_LIVE_UPDATE, bytes)
    }
}
