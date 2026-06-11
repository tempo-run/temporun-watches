package com.temporun.run.wear.training

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PaceAlertEvaluatorTest {

    // Tempo Run com alvo 5:00-5:30/km (300-330 s/km)
    private val tempo = DailyWorkout(dia = "Segunda", tipo = "Tempo Run", distanciaKm = 8.0, paceAlvo = "5:00-5:30/km")

    @Test
    fun `nao alerta no primeiro minuto`() {
        val e = PaceAlertEvaluator()
        val r = e.evaluate(tempo, currentPaceSec = 270.0, elapsedSec = 30.0) // muito rápido, mas <60s
        assertNull(r.alert)
        assertFalse(r.changed)
    }

    @Test
    fun `dispara na transicao para muito rapido e nao re-dispara enquanto persiste`() {
        val e = PaceAlertEvaluator()
        val first = e.evaluate(tempo, 270.0, 120.0)   // 270 < 300*0.95 → TOO_FAST
        assertEquals(PaceStatus.TOO_FAST, first.alert?.status)
        assertTrue(first.changed)

        val second = e.evaluate(tempo, 265.0, 121.0)  // ainda rápido
        assertEquals(PaceStatus.TOO_FAST, second.alert?.status)
        assertFalse("não deve re-disparar haptic", second.changed)
    }

    @Test
    fun `voltar para a zona limpa o alerta e marca mudanca`() {
        val e = PaceAlertEvaluator()
        e.evaluate(tempo, 270.0, 120.0)               // TOO_FAST
        val back = e.evaluate(tempo, 315.0, 130.0)    // dentro da zona
        assertNull(back.alert)
        assertTrue(back.changed)
    }

    @Test
    fun `muito lento dispara`() {
        val e = PaceAlertEvaluator()
        val r = e.evaluate(tempo, 360.0, 120.0)       // 360 > 330*1.05 → TOO_SLOW
        assertEquals(PaceStatus.TOO_SLOW, r.alert?.status)
        assertTrue(r.changed)
    }

    @Test
    fun `descanso e plano nulo nunca alertam`() {
        val e = PaceAlertEvaluator()
        val rest = DailyWorkout(dia = "Domingo", tipo = "Descanso", paceAlvo = "5:00/km")
        assertNull(e.evaluate(rest, 200.0, 600.0).alert)
        assertNull(e.evaluate(null, 200.0, 600.0).alert)
    }
}
