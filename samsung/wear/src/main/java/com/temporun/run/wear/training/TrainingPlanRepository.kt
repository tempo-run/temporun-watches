package com.temporun.run.wear.training

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Mantém o plano de treino ativo recebido do celular e calcula alertas de pace por zona.
 * Equivalente ao TrainingPlanManager.swift.
 *
 * Fase 0: estrutura + estado observável.
 * TODO(Fase 3): receber plano via Data Layer, cache em DataStore, checkPaceAlert() com haptic
 *               (directionUp/Down) quando o pace sai da zona-alvo, e requestPlanFromPhone().
 */
class TrainingPlanRepository {

    private val _plan = MutableStateFlow<TrainingPlan?>(null)
    val plan: StateFlow<TrainingPlan?> = _plan.asStateFlow()

    private val _todayWorkout = MutableStateFlow<DailyWorkout?>(null)
    val todayWorkout: StateFlow<DailyWorkout?> = _todayWorkout.asStateFlow()

    fun apply(plan: TrainingPlan) {
        _plan.value = plan
        _todayWorkout.value = plan.todayWorkout()
    }

    fun checkPaceAlert(currentPaceSec: Double, elapsedTimeSec: Double): PaceStatus {
        val workout = _todayWorkout.value ?: return PaceStatus.OK
        if (workout.workoutType.isRest || elapsedTimeSec <= 60) return PaceStatus.OK
        return workout.isPaceOnTarget(currentPaceSec)
    }
}
