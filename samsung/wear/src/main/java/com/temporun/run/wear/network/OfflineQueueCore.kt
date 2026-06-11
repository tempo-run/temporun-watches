package com.temporun.run.wear.network

import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Corrida pendente (corpo JSON já no contrato) + nº de tentativas. */
@Serializable
data class PendingRun(val body: String, val attempts: Int = 0)

/**
 * Lógica pura da fila offline (sem Android) — testável na JVM. Espelha OfflineQueue.swift:
 * persiste corridas que falharam ao gravar standalone e tenta reenviar quando há rede,
 * descartando após [maxAttempts] para não travar a fila.
 */
class OfflineQueueCore(
    private val store: QueueStore,
    private val maxAttempts: Int = 5,
) {
    interface QueueStore {
        fun load(): List<PendingRun>
        fun save(list: List<PendingRun>)
    }

    fun enqueue(body: String) {
        store.save(store.load() + PendingRun(body))
    }

    fun pending(): Int = store.load().size

    /** Tenta enviar cada item; remove no sucesso, incrementa tentativa na falha, descarta após máx. */
    suspend fun syncAll(send: suspend (String) -> Boolean): Int {
        var synced = 0
        val remaining = mutableListOf<PendingRun>()
        for (item in store.load()) {
            when {
                item.attempts >= maxAttempts -> {} // descarta silenciosamente
                send(item.body) -> synced++
                else -> remaining.add(item.copy(attempts = item.attempts + 1))
            }
        }
        store.save(remaining)
        return synced
    }

    companion object {
        private val json = Json { ignoreUnknownKeys = true }
        fun encode(list: List<PendingRun>): String = json.encodeToString(list)
        fun decode(s: String?): List<PendingRun> =
            if (s.isNullOrEmpty()) emptyList()
            else runCatching { json.decodeFromString<List<PendingRun>>(s) }.getOrDefault(emptyList())
    }
}
