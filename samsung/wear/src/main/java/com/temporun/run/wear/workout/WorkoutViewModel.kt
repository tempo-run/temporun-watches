package com.temporun.run.wear.workout

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Orquestra o estado da corrida e expõe métricas/tempo para a UI Compose.
 * Equivalente ao papel de coordenação do WorkoutManager.swift (a captura de sensores
 * em si vive no [ExerciseManager]).
 */
class WorkoutViewModel(app: Application) : AndroidViewModel(app) {

    private val exerciseManager = ExerciseManager(app)

    private val _state = MutableStateFlow(WorkoutState.IDLE)
    val state: StateFlow<WorkoutState> = _state.asStateFlow()

    val metrics: StateFlow<LiveMetrics> = exerciseManager.metrics

    private val _elapsedSeconds = MutableStateFlow(0L)
    val elapsedSeconds: StateFlow<Long> = _elapsedSeconds.asStateFlow()

    private var timerJob: Job? = null

    fun start() {
        viewModelScope.launch {
            runCatching { exerciseManager.start() }
            _state.value = WorkoutState.RUNNING
            startTimer()
        }
    }

    fun togglePause() {
        viewModelScope.launch {
            when (_state.value) {
                WorkoutState.RUNNING -> {
                    runCatching { exerciseManager.pause() }
                    _state.value = WorkoutState.PAUSED
                    timerJob?.cancel()
                }
                WorkoutState.PAUSED -> {
                    runCatching { exerciseManager.resume() }
                    _state.value = WorkoutState.RUNNING
                    startTimer()
                }
                else -> {}
            }
        }
    }

    fun end() {
        viewModelScope.launch {
            runCatching { exerciseManager.end() }
            timerJob?.cancel()
            _state.value = WorkoutState.ENDED
            // TODO(Fase 2/5): montar WorkoutPayload e enviar via DataLayerManager
            //                 ou gravar via SupabaseClient (modo standalone).
        }
    }

    fun reset() {
        exerciseManager.reset()
        _elapsedSeconds.value = 0L
        _state.value = WorkoutState.IDLE
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (isActive) {
                delay(1000)
                _elapsedSeconds.value += 1
            }
        }
    }
}
