package com.temporun.run.wear.connectivity

import com.temporun.run.wear.workout.KmSplit
import com.temporun.run.wear.workout.LiveMetrics
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * O JSON enviado ao celular (e repassado à edge function) deve refletir EXATAMENTE o mapa do
 * contrato, inclusive os splits aninhados. Isso garante que o transporte do Data Layer não
 * altera o contrato auditado.
 */
class SupabaseBodyTest {

    private fun payload() = WorkoutPayload.from(
        metrics = LiveMetrics(
            distanceKm = 5.0,
            averageHeartRate = 148.0,
            timeInZone = listOf(0.0, 60.0, 300.0, 600.0, 500.0, 100.0),
            activeEnergyBurned = 350.0,
            splits = listOf(KmSplit(km = 1, durationSec = 335.0, paceSec = 335.0, avgHeartRate = 145.0, elevationGain = 8.0)),
        ),
        elapsedTimeSec = 1700.0,
        startDateIso = "2026-06-09T08:00:00Z",
        endDateIso = "2026-06-09T08:28:20Z",
        source = "wear_os",
    )

    @Test
    fun `json e valido e tem as mesmas chaves do mapa do contrato`() {
        val map = payload().toSupabaseMap()
        val obj = Json.parseToJsonElement(map.toJsonString()) as JsonObject
        assertEquals(map.keys, obj.keys)
    }

    @Test
    fun `splits aninhados preservam as chaves e valores`() {
        val obj = Json.parseToJsonElement(payload().toSupabaseMap().toJsonString()) as JsonObject
        val split = (obj["splits"] as JsonArray).single().jsonObject
        assertEquals(setOf("km", "duracao", "pace", "fc_media", "ganho_elevacao"), split.keys)
        assertEquals(1, split["km"]!!.jsonPrimitive.content.toInt())
        assertEquals(335.0, split["pace"]!!.jsonPrimitive.content.toDouble(), 0.001)
    }

    @Test
    fun `null vira JSON null e numeros sao numericos`() {
        val json = mapOf("a" to null, "b" to 5, "c" to 1.5, "d" to "x").toJsonString()
        val obj = Json.parseToJsonElement(json) as JsonObject
        assertTrue(obj["a"] is kotlinx.serialization.json.JsonNull)
        assertEquals("5", obj["b"]!!.jsonPrimitive.content)
        assertEquals("x", obj["d"]!!.jsonPrimitive.content)
    }

    @Test
    fun `live update round-trip`() {
        val u = LiveUpdate(distanceKm = 3.2, paceSec = 330.0, heartRate = 152.0, elapsedSec = 900)
        val back = LiveUpdate.fromBytes(u.toBytes())
        assertEquals(u, back)
    }
}
