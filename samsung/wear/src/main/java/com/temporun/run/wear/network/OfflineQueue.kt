package com.temporun.run.wear.network

import com.temporun.run.wear.connectivity.WorkoutPayload

/**
 * Fila offline de corridas pendentes (modo standalone sem rede). Equivalente ao
 * OfflineQueue.swift.
 *
 * TODO(Fase 5): persistir com Room e sincronizar via WorkManager (backoff exponencial,
 *               máx. de tentativas), disparando o sync quando a rede voltar (NetworkMonitor).
 */
object OfflineQueue {
    fun enqueue(payload: WorkoutPayload) {
        // TODO(Fase 5)
    }

    suspend fun syncAll() {
        // TODO(Fase 5)
    }
}
