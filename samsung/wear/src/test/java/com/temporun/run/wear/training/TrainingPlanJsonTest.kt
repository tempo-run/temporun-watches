package com.temporun.run.wear.training

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Garante que o JSON do row planos_treino enviado pelo celular desserializa no modelo do
 * relógio — incluindo campos extras (ignoreUnknownKeys) e a estrutura semanas→dias.
 */
class TrainingPlanJsonTest {

    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    private val sample = """
        {
          "id": "plan-123",
          "objetivo": "Maratona sub-4",
          "nivel": "intermediario",
          "ativo": true,
          "campo_extra_ignorado": 42,
          "semanas": [
            {
              "semana": 1,
              "foco": "Base",
              "volume_km": 40.0,
              "resumo": "Semana de adaptação",
              "intensidade": "leve",
              "dias": [
                {"dia":"Segunda","tipo":"Rodagem Leve","distancia_km":8.0,"pace_alvo":"6:30-7:00/km","descricao":"Trote regenerativo","detalhe_treino":"aquecimento + 8km + desaq","alerta_lesao":""},
                {"dia":"Terça","tipo":"Tempo Run","distancia_km":10.0,"pace_alvo":"5:10-5:30/km","descricao":"Limiar","detalhe_treino":"3x2km","alerta_lesao":"cuidado com canela"},
                {"dia":"Domingo","tipo":"Descanso","distancia_km":0.0,"pace_alvo":"","descricao":"","detalhe_treino":"","alerta_lesao":""}
              ]
            }
          ]
        }
    """.trimIndent()

    @Test
    fun `desserializa plano completo com campos extras`() {
        val plan = json.decodeFromString<TrainingPlan>(sample)
        assertEquals("plan-123", plan.id)
        assertTrue(plan.ativo)
        assertEquals(1, plan.semanas.size)
        assertEquals(3, plan.currentWeek?.dias?.size)
    }

    @Test
    fun `dia mapeia para WorkoutType e pace range`() {
        val plan = json.decodeFromString<TrainingPlan>(sample)
        val tempo = plan.currentWeek!!.dias!!.first { it.tipo == "Tempo Run" }
        assertEquals(WorkoutType.TEMPO_RUN, tempo.workoutType)
        val range = tempo.paceRangeSec()
        assertNotNull(range)
        assertEquals(310.0, range!!.first, 0.001)   // 5:10
        assertEquals(330.0, range.second, 0.001)    // 5:30
        assertTrue(plan.currentWeek!!.dias!!.first { it.dia == "Domingo" }.workoutType.isRest)
    }
}
