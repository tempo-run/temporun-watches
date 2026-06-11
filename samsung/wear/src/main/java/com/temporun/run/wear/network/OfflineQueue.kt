package com.temporun.run.wear.network

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Fila offline persistida (modo standalone sem rede). Wrapper Android sobre [OfflineQueueCore]:
 * armazena em SharedPreferences e envia via [SupabaseClient]. Equivalente ao OfflineQueue.swift.
 */
object OfflineQueue {

    private const val PREFS = "temporun_wear"
    private const val KEY = "offlineQueue"

    private lateinit var appContext: Context
    private var core: OfflineQueueCore? = null

    private val _pending = MutableStateFlow(0)
    val pending: StateFlow<Int> = _pending.asStateFlow()

    @Volatile private var initialized = false

    fun ensureInit(context: Context) {
        if (initialized) return
        appContext = context.applicationContext
        core = OfflineQueueCore(PrefsStore(appContext))
        initialized = true
        refresh()
    }

    fun enqueue(body: String) {
        core?.enqueue(body)
        refresh()
    }

    suspend fun syncAll() {
        val c = core ?: return
        c.syncAll { body -> SupabaseClient.insertCorrida(appContext, body).ok }
        refresh()
    }

    private fun refresh() {
        _pending.value = core?.pending() ?: 0
    }

    private class PrefsStore(private val context: Context) : OfflineQueueCore.QueueStore {
        private fun prefs() = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        override fun load() = OfflineQueueCore.decode(prefs().getString(KEY, null))
        override fun save(list: List<PendingRun>) {
            prefs().edit().putString(KEY, OfflineQueueCore.encode(list)).apply()
        }
    }
}
