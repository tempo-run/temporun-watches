package com.temporun.run.wear.training

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.Calendar

/**
 * Modelos do plano de treino. Espelham TrainingPlan.swift do Apple Watch e o formato
 * exato do SYS_PLAN_WEEK (tabela planos_treino do Supabase). Recebidos do celular via
 * Data Layer na Fase 3.
 */

enum class WorkoutIntensity { REST, EASY, MODERATE, HARD }

enum class PaceStatus { OK, TOO_FAST, TOO_SLOW }

/** 13 tipos de treino permitidos pelo SYS_PLAN_WEEK. */
enum class WorkoutType(val raw: String) {
    RODAGEM_LEVE("Rodagem Leve"),
    RODAGEM_MODERADA("Rodagem Moderada"),
    RODAGEM_PROGRESSIVA("Rodagem Progressiva"),
    LONGAO_LENTO("Longão Lento"),
    LONGAO_COM_RITMO("Longão com Ritmo"),
    LONGAO_PROGRESSIVO("Longão Progressivo"),
    TEMPO_RUN("Tempo Run"),
    INTERVALADO("Intervalado"),
    FARTLEK("Fartlek"),
    SUBIDAS("Subidas"),
    STRIDES("Strides"),
    DESCANSO("Descanso"),
    DESCANSO_ATIVO("Descanso Ativo");

    val isRest: Boolean get() = this == DESCANSO || this == DESCANSO_ATIVO

    val isQuality: Boolean
        get() = this in setOf(TEMPO_RUN, INTERVALADO, FARTLEK, SUBIDAS, STRIDES)

    val intensity: WorkoutIntensity
        get() = when (this) {
            DESCANSO, DESCANSO_ATIVO -> WorkoutIntensity.REST
            RODAGEM_LEVE, LONGAO_LENTO -> WorkoutIntensity.EASY
            RODAGEM_MODERADA, RODAGEM_PROGRESSIVA, FARTLEK,
            STRIDES, LONGAO_COM_RITMO, LONGAO_PROGRESSIVO -> WorkoutIntensity.MODERATE
            TEMPO_RUN, INTERVALADO, SUBIDAS -> WorkoutIntensity.HARD
        }

    companion object {
        fun fromRaw(raw: String): WorkoutType =
            entries.firstOrNull { it.raw == raw } ?: RODAGEM_LEVE
    }
}

@Serializable
data class DailyWorkout(
    val dia: String,                  // "Segunda", "Terça", ...
    val tipo: String,                 // raw string do JSON
    @SerialName("distancia_km") val distanciaKm: Double = 0.0,
    @SerialName("pace_alvo") val paceAlvo: String = "",  // "6:30-7:00/km" ou "6:30/km"
    val descricao: String = "",
    @SerialName("detalhe_treino") val detalheTreino: String = "",
    @SerialName("alerta_lesao") val alertaLesao: String = "",
) {
    val workoutType: WorkoutType get() = WorkoutType.fromRaw(tipo)

    /** "6:30-7:00/km" → Pair(lower, upper) em seg/km. */
    fun paceRangeSec(): Pair<Double, Double>? {
        val cleaned = paceAlvo.replace("/km", "")
        val parts = cleaned.split("-").map { it.trim() }
        fun toSec(s: String): Double? {
            val p = s.split(":").mapNotNull { it.toDoubleOrNull() }
            return if (p.size == 2) p[0] * 60 + p[1] else null
        }
        return when {
            parts.size == 2 -> {
                val lo = toSec(parts[0]); val hi = toSec(parts[1])
                if (lo != null && hi != null) lo to hi else null
            }
            parts.size == 1 -> toSec(parts[0])?.let { it * 0.97 to it * 1.03 }
            else -> null
        }
    }

    fun isPaceOnTarget(currentPaceSec: Double): PaceStatus {
        if (workoutType.isRest || currentPaceSec <= 0) return PaceStatus.OK
        val range = paceRangeSec() ?: return PaceStatus.OK
        return when {
            currentPaceSec < range.first * 0.95 -> PaceStatus.TOO_FAST
            currentPaceSec > range.second * 1.05 -> PaceStatus.TOO_SLOW
            else -> PaceStatus.OK
        }
    }
}

@Serializable
data class TrainingWeek(
    val semana: Int = 0,
    val foco: String = "",
    @SerialName("volume_km") val volumeKm: Double = 0.0,
    val resumo: String = "",
    val intensidade: String = "",
    val dias: List<DailyWorkout>? = null,
)

@Serializable
data class TrainingPlan(
    val id: String = "",
    val objetivo: String = "",
    val nivel: String = "",
    val semanas: List<TrainingWeek> = emptyList(),
    val ativo: Boolean = false,
) {
    fun todayWorkout(): DailyWorkout? {
        val names = listOf("Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado")
        val weekday = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) // 1=Dom..7=Sáb
        val todayName = names[weekday - 1]
        for (week in semanas) {
            week.dias?.firstOrNull { it.dia == todayName }?.let { return it }
        }
        return null
    }

    val currentWeek: TrainingWeek? get() = semanas.firstOrNull { it.dias != null }
}
