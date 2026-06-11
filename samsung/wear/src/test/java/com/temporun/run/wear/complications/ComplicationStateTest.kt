package com.temporun.run.wear.complications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ComplicationStateTest {

    @Test
    fun `weeklyProgress trata meta zero e satura em 1`() {
        assertEquals(0f, ComplicationState(weeklyKm = 10.0, weeklyGoalKm = 0.0).weeklyProgress, 0.0001f)
        assertEquals(0.5f, ComplicationState(weeklyKm = 20.0, weeklyGoalKm = 40.0).weeklyProgress, 0.0001f)
        assertEquals(1f, ComplicationState(weeklyKm = 50.0, weeklyGoalKm = 40.0).weeklyProgress, 0.0001f)
    }

    @Test
    fun `label do proximo treino`() {
        assertEquals("Sem treino", ComplicationState().nextWorkoutLabel())
        assertEquals(
            "Qua: Tempo Run · 8km",
            ComplicationState(nextWorkoutType = "Tempo Run", nextWorkoutKm = 8.0, nextWorkoutDay = "Qua").nextWorkoutLabel(),
        )
        // distância fracionária preserva 1 casa
        assertTrue(
            ComplicationState(nextWorkoutType = "Longão", nextWorkoutKm = 12.5, nextWorkoutDay = "Dom")
                .nextWorkoutLabel().contains("12.5km"),
        )
    }

    @Test
    fun `json round-trip e tolerante a lixo e campos extras`() {
        val s = ComplicationState(weeklyKm = 24.0, weeklyGoalKm = 40.0, streakDays = 5, xp = 1200,
            nextWorkoutType = "Tempo Run", nextWorkoutKm = 8.0, nextWorkoutDay = "Qua")
        assertEquals(s, ComplicationState.fromJson(s.toJson()))
        assertEquals(ComplicationState(), ComplicationState.fromJson(null))
        assertEquals(ComplicationState(), ComplicationState.fromJson("{lixo"))
        // campo desconhecido é ignorado
        val withExtra = """{"weeklyKm":3.0,"campo_novo":99}"""
        assertEquals(3.0, ComplicationState.fromJson(withExtra).weeklyKm, 0.0001)
    }
}
