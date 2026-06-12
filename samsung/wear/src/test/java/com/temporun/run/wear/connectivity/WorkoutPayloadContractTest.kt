package com.temporun.run.wear.connectivity

import com.temporun.run.wear.workout.KmSplit
import com.temporun.run.wear.workout.LiveMetrics
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * TESTE DE CONTRATO — trava as chaves de toSupabaseMap() contra a interface
 * WatchWorkoutPayload da edge function watch-workout-save
 * (apple/supabase/functions/watch-workout-save/index.ts).
 *
 * Se este teste quebrar, ou o Kotlin divergiu do contrato, ou o contrato mudou —
 * nos dois casos é exatamente o tipo de bug silencioso documentado em CONTRACT_AUDIT.md
 * (chave com nome errado → undefined no Deno → coluna NULL no banco).
 */
class WorkoutPayloadContractTest {

    private fun samplePayload(source: String = "wear_os") = WorkoutPayload.from(
        metrics = LiveMetrics(
            distanceKm = 5.0,
            currentPace = 330.0,
            averagePace = 340.0,
            bestPace = 310.0,
            currentSpeed = 3.0,
            stepCount = 5000.0,
            cadence = 172.0,
            heartRate = 150.0,
            averageHeartRate = 148.0,
            minHeartRate = 92.0,
            maxHeartRate = 176.0,
            vo2Max = 50.0,
            timeInZone = listOf(0.0, 60.0, 300.0, 600.0, 500.0, 100.0),
            activeEnergyBurned = 350.0,
            basalEnergyBurned = 40.0,
            elevationGain = 42.0,
            elevationLoss = 38.0,
            currentAltitude = 25.0,
            maxAltitude = 60.0,
            minAltitude = 10.0,
            splits = listOf(KmSplit(km = 1, durationSec = 335.0, paceSec = 335.0, avgHeartRate = 145.0, elevationGain = 8.0)),
        ),
        elapsedTimeSec = 1700.0,
        startDateIso = "2026-06-09T08:00:00Z",
        endDateIso = "2026-06-09T08:28:20Z",
        source = source,
    )

    @Test
    fun `chaves do mapa batem exatamente com o contrato da edge function`() {
        // Campos da interface WatchWorkoutPayload que o Wear envia
        // (os ausentes — physical_effort, fc_repouso, hrv_sdnn, spo2, frequencia_resp,
        //  plano_id, plano_semana, treino_tipo — não são fornecidos pelo Health Services 1.0.0
        //  ou chegam só na Fase 3). "device" é extra deliberado, ignorado pela função.
        // Biomecânica (stride_length, running_power, ground_contact, vertical_osc,
        // vertical_ratio) é OMITIDA quando 0 → NULL no banco. O sample não tem esses dados.
        val expected = setOf(
            "distancia_km", "duracao_seg", "pace_medio", "pace_melhor", "velocidade_media",
            "step_count", "cadencia", "bpm_medio", "fc_min", "fc_max", "vo2_estimado",
            "tempo_zona1", "tempo_zona2", "tempo_zona3", "tempo_zona4", "tempo_zona5",
            "calorias_ativas", "calorias_basais", "calorias_total",
            "ganho_elevacao", "perda_elevacao", "altitude_max", "altitude_min",
            "splits", "data_inicio", "data_fim", "source", "device",
        )
        assertEquals(expected, samplePayload().toSupabaseMap().keys)
    }

    @Test
    fun `biomecanica zerada e omitida e presente quando ha dado`() {
        val omit = setOf("stride_length", "running_power", "ground_contact", "vertical_osc", "vertical_ratio")
        // Sem dado → chaves ausentes
        assertTrue(samplePayload().toSupabaseMap().keys.intersect(omit).isEmpty())
        // Com dado → chaves presentes
        val withBio = WorkoutPayload.from(
            metrics = LiveMetrics(distanceKm = 1.0, runningPower = 280.0, strideLength = 1.2,
                groundContactTime = 240.0, verticalOscillation = 8.5, verticalRatio = 7.0),
            elapsedTimeSec = 300.0, startDateIso = "x", endDateIso = "y", source = "wear_os",
        ).toSupabaseMap()
        assertTrue(withBio.keys.containsAll(omit))
        assertEquals(280.0, withBio["running_power"])
    }

    @Test
    fun `itens de split usam as chaves esperadas pela funcao`() {
        val map = samplePayload().toSupabaseMap()
        @Suppress("UNCHECKED_CAST")
        val splits = map["splits"] as List<Map<String, Any?>>
        assertEquals(setOf("km", "duracao", "pace", "fc_media", "ganho_elevacao"), splits.single().keys)
    }

    @Test
    fun `valores numericos e derivados sao consistentes`() {
        val map = samplePayload().toSupabaseMap()
        assertEquals(5.0, map["distancia_km"])
        assertEquals(1700, map["duracao_seg"])
        assertEquals(390.0, map["calorias_total"])   // ativas + basais
        // velocidade_media é a MÉDIA (dist/tempo), não a instantânea: 5000 m / 1700 s
        assertEquals(5000.0 / 1700.0, map["velocidade_media"] as Double, 0.001)
        assertEquals(60.0, map["tempo_zona1"])
        assertEquals(100.0, map["tempo_zona5"])
        assertEquals("wear_os", map["source"])
        assertEquals("wear_os", map["device"])
    }

    @Test
    fun `source standalone propaga para device`() {
        val map = samplePayload(source = "wear_os_standalone").toSupabaseMap()
        assertEquals("wear_os_standalone", map["source"])
        assertEquals("wear_os_standalone", map["device"])
    }

    @Test
    fun `nenhuma chave do mapa usa os nomes errados da auditoria`() {
        val forbidden = setOf(
            "ground_contact_time", "vertical_oscillation", "frequencia_cardiaca_media",
            "frequencia_cardiaca_min", "frequencia_cardiaca_max", "frequencia_respiratoria",
        )
        val keys = samplePayload().toSupabaseMap().keys
        assertTrue(keys.intersect(forbidden).isEmpty())
    }
}
