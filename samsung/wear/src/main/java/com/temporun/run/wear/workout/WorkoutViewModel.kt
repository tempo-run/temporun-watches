package com.temporun.run.wear.workout

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import kotlinx.coroutines.flow.StateFlow

/**
 * Fachada fina sobre o [WorkoutSessionHolder]. A posse real da sessão (timer, callback do
 * Health Services, estado) vive no holder em escopo de Application — assim a corrida sobrevive
 * à destruição/recriação da UI (swipe-to-dismiss, rotação, retorno pela notificação).
 */
class WorkoutViewModel(app: Application) : AndroidViewModel(app) {

    init { WorkoutSessionHolder.ensureInit(app) }

    val state: StateFlow<WorkoutState> = WorkoutSessionHolder.state
    val metrics: StateFlow<LiveMetrics> = WorkoutSessionHolder.metrics
    val elapsedSeconds: StateFlow<Long> = WorkoutSessionHolder.elapsedSeconds

    fun start() = WorkoutSessionHolder.start()
    fun togglePause() = WorkoutSessionHolder.togglePause()
    fun end() = WorkoutSessionHolder.end()
    fun reset() = WorkoutSessionHolder.reset()
}
