package com.temporun.run.wear.complications

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Dados de glanceability (complications + tile). Espelha a struct ComplicationData do Apple:
 * km da semana, meta, streak, XP e o próximo treino. Enviado do celular via Data Layer.
 * Lógica pura — testável na JVM.
 */
@Serializable
data class ComplicationState(
    val weeklyKm: Double = 0.0,
    val weeklyGoalKm: Double = 0.0,
    val streakDays: Int = 0,
    val xp: Int = 0,
    val nextWorkoutType: String = "",
    val nextWorkoutKm: Double = 0.0,
    val nextWorkoutDay: String = "",
) {
    /** Fração 0..1 do progresso semanal (para o gauge/ring). */
    val weeklyProgress: Float
        get() = if (weeklyGoalKm > 0) (weeklyKm / weeklyGoalKm).coerceIn(0.0, 1.0).toFloat() else 0f

    fun weeklyKmInt(): Int = weeklyKm.toInt()

    /** Resumo do próximo treino para texto curto/longo. */
    fun nextWorkoutLabel(): String = when {
        nextWorkoutType.isEmpty() -> "Sem treino"
        else -> {
            val km = if (nextWorkoutKm % 1.0 == 0.0) nextWorkoutKm.toInt().toString() else "%.1f".format(nextWorkoutKm)
            val dia = nextWorkoutDay.ifEmpty { "Próximo" }
            "$dia: $nextWorkoutType · ${km}km"
        }
    }

    fun toJson(): String = Json.encodeToString(serializer(), this)

    companion object {
        fun fromJson(s: String?): ComplicationState =
            if (s.isNullOrEmpty()) ComplicationState()
            else runCatching { Json { ignoreUnknownKeys = true }.decodeFromString(serializer(), s) }
                .getOrDefault(ComplicationState())
    }
}
