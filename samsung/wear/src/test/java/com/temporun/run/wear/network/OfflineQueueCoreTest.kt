package com.temporun.run.wear.network

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OfflineQueueCoreTest {

    /** Store em memória para testar a lógica sem Android. */
    private class MemStore(var items: MutableList<PendingRun> = mutableListOf()) : OfflineQueueCore.QueueStore {
        override fun load() = items.toList()
        override fun save(list: List<PendingRun>) { items = list.toMutableList() }
    }

    @Test
    fun `enqueue acumula e pending reflete`() {
        val store = MemStore()
        val q = OfflineQueueCore(store)
        q.enqueue("a"); q.enqueue("b")
        assertEquals(2, q.pending())
    }

    @Test
    fun `syncAll remove os enviados e mantem os que falharam`() = runBlocking {
        val store = MemStore(mutableListOf(PendingRun("ok1"), PendingRun("fail"), PendingRun("ok2")))
        val q = OfflineQueueCore(store)
        val synced = q.syncAll { body -> body.startsWith("ok") }
        assertEquals(2, synced)
        assertEquals(listOf("fail"), store.items.map { it.body })
        assertEquals(1, store.items.single().attempts) // tentativa incrementada
    }

    @Test
    fun `descarta apos maxAttempts`() = runBlocking {
        val store = MemStore(mutableListOf(PendingRun("x", attempts = 5)))
        val q = OfflineQueueCore(store, maxAttempts = 5)
        val synced = q.syncAll { false }
        assertEquals(0, synced)
        assertTrue("item esgotado deve ser descartado", store.items.isEmpty())
    }

    @Test
    fun `encode-decode round-trip e decode tolerante a lixo`() {
        val list = listOf(PendingRun("a", 1), PendingRun("b", 0))
        assertEquals(list, OfflineQueueCore.decode(OfflineQueueCore.encode(list)))
        assertTrue(OfflineQueueCore.decode(null).isEmpty())
        assertTrue(OfflineQueueCore.decode("{lixo").isEmpty())
    }
}
