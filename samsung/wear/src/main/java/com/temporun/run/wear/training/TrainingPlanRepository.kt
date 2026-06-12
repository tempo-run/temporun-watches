package com.temporun.run.wear.training

import android.content.Context
import com.temporun.run.wear.workout.Haptics
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json

/**
 * Mantém o plano de treino ativo (recebido do celular via Data Layer) e dispara os alertas de
 * pace por zona durante a corrida. Equivalente ao TrainingPlanManager.swift.
 *
 * Singleton em escopo de Application (como o WorkoutSessionHolder): o plano sobrevive à
 * recriação da UI e fica disponível para o serviço que recebe os dados do Data Layer.
 */
object TrainingPlanRepository {

    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }
    private const val PREFS = "temporun_wear"
    private const val KEY_PLAN = "trainingPlanJson"

    private var appContext: Context? = null
    private var haptics: Haptics? = null
    private val evaluator = PaceAlertEvaluator()

    private val _plan = MutableStateFlow<TrainingPlan?>(null)
    val plan: StateFlow<TrainingPlan?> = _plan.asStateFlow()

    private val _todayWorkout = MutableStateFlow<DailyWorkout?>(null)
    val todayWorkout: StateFlow<DailyWorkout?> = _todayWorkout.asStateFlow()

    private val _weekWorkouts = MutableStateFlow<List<DailyWorkout>>(emptyList())
    val weekWorkouts: StateFlow<List<DailyWorkout>> = _weekWorkouts.asStateFlow()

    private val _paceAlert = MutableStateFlow<PaceAlert?>(null)
    val paceAlert: StateFlow<PaceAlert?> = _paceAlert.asStateFlow()

    fun ensureInit(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        haptics = Haptics(context.applicationContext)
        // Carrega plano em cache (última sincronização).
        prefs()?.getString(KEY_PLAN, null)?.let { applyJson(it, persist = false) }
    }

    /** Recebe o plano (JSON do row planos_treino) do celular e o aplica + cacheia. */
    fun applyJson(planJson: String, persist: Boolean = true) {
        val plan = runCatching { json.decodeFromString<TrainingPlan>(planJson) }.getOrNull() ?: return
        _plan.value = plan
        _todayWorkout.value = plan.todayWorkout()
        _weekWorkouts.value = plan.currentWeek?.dias ?: emptyList()
        if (persist) prefs()?.edit()?.putString(KEY_PLAN, planJson)?.apply()
    }

    /**
     * Avalia o pace durante a corrida; dispara haptic apenas na TRANSIÇÃO de status e atualiza
     * o [paceAlert] para a UI. Chamado pelo WorkoutSessionHolder a cada tick.
     */
    fun evaluatePace(currentPaceSec: Double, elapsedSec: Double) {
        val result = evaluator.evaluate(_todayWorkout.value, currentPaceSec, elapsedSec)
        _paceAlert.value = result.alert
        if (result.changed) {
            when (result.alert?.status) {
                PaceStatus.TOO_FAST -> haptics?.paceTooFast()
                PaceStatus.TOO_SLOW -> haptics?.paceTooSlow()
                else -> {}
            }
        }
    }

    fun clearAlert() {
        evaluator.reset()
        _paceAlert.value = null
    }

    private fun prefs() = appContext?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
