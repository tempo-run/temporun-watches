package com.temporun.run.wear.training

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class TrainingPlanTest {

    private fun workout(tipo: String = "Rodagem Leve", pace: String = "") = DailyWorkout(
        dia = "Segunda", tipo = tipo, distanciaKm = 8.0, paceAlvo = pace,
    )

    @Test
    fun `parse de faixa de pace min-max`() {
        val range = workout(pace = "6:30-7:00/km").paceRangeSec()
        assertNotNull(range)
        assertEquals(390.0, range!!.first, 0.001)
        assertEquals(420.0, range.second, 0.001)
    }

    @Test
    fun `parse de pace unico vira faixa de mais ou menos 3 por cento`() {
        val range = workout(pace = "6:00/km").paceRangeSec()
        assertNotNull(range)
        assertEquals(360.0 * 0.97, range!!.first, 0.001)
        assertEquals(360.0 * 1.03, range.second, 0.001)
    }

    @Test
    fun `pace invalido retorna null`() {
        assertNull(workout(pace = "livre").paceRangeSec())
        assertNull(workout(pace = "").paceRangeSec())
    }

    @Test
    fun `status do pace contra a faixa alvo`() {
        val w = workout(tipo = "Tempo Run", pace = "5:00-5:30/km") // 300-330 s/km
        assertEquals(PaceStatus.OK, w.isPaceOnTarget(310.0))
        assertEquals(PaceStatus.TOO_FAST, w.isPaceOnTarget(270.0))  // < 300*0.95
        assertEquals(PaceStatus.TOO_SLOW, w.isPaceOnTarget(350.0))  // > 330*1.05
        assertEquals(PaceStatus.OK, w.isPaceOnTarget(0.0))          // sem leitura
    }

    @Test
    fun `descanso nunca alerta`() {
        val w = workout(tipo = "Descanso", pace = "5:00/km")
        assertEquals(PaceStatus.OK, w.isPaceOnTarget(999.0))
    }

    @Test
    fun `mapeamento dos 13 tipos e fallback`() {
        assertEquals(WorkoutType.TEMPO_RUN, WorkoutType.fromRaw("Tempo Run"))
        assertEquals(WorkoutType.LONGAO_COM_RITMO, WorkoutType.fromRaw("Longão com Ritmo"))
        assertEquals(WorkoutType.RODAGEM_LEVE, WorkoutType.fromRaw("tipo desconhecido"))
        assertEquals(13, WorkoutType.entries.size)
    }
}
