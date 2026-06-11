package com.temporun.run.wear.training

/** Alerta de pace ativo (para a UI e o haptic). */
data class PaceAlert(val status: PaceStatus, val paceAlvo: String)

/** Resultado de uma avaliação: alerta atual + se MUDOU desde a última (dispara haptic só na mudança). */
data class PaceAlertResult(val alert: PaceAlert?, val changed: Boolean)

/**
 * Lógica pura do alerta de pace por zona. Espelha TrainingPlanManager.checkPaceAlert do Apple:
 * só alerta após 1 min de corrida, e o haptic dispara apenas na TRANSIÇÃO de status
 * (evita vibração contínua). Sem dependência de Android — testável na JVM.
 */
class PaceAlertEvaluator {

    private var lastStatus: PaceStatus = PaceStatus.OK

    fun evaluate(workout: DailyWorkout?, currentPaceSec: Double, elapsedSec: Double): PaceAlertResult {
        if (workout == null || workout.workoutType.isRest || elapsedSec <= 60 || currentPaceSec <= 0) {
            return settle(PaceStatus.OK, null)
        }
        val status = workout.isPaceOnTarget(currentPaceSec)
        val alert = if (status == PaceStatus.OK) null else PaceAlert(status, workout.paceAlvo)
        return settle(status, alert)
    }

    private fun settle(status: PaceStatus, alert: PaceAlert?): PaceAlertResult {
        val changed = status != lastStatus
        lastStatus = status
        return PaceAlertResult(alert, changed)
    }

    fun reset() { lastStatus = PaceStatus.OK }
}
