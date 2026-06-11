package com.temporun.run.wear.workout

import android.content.Context
import android.content.Intent
import com.temporun.run.wear.connectivity.DataLayerManager
import com.temporun.run.wear.connectivity.WorkoutPayload
import com.temporun.run.wear.training.TrainingPlanRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Dono da sessão de corrida, em escopo de **Application** (não da Activity).
 *
 * Motivo (revisão Fase 1): se a posse vivesse no ViewModel da Activity, o swipe-to-dismiss
 * destruiria o `viewModelScope` no meio da corrida — o timer pararia, ninguém chamaria
 * `end()`, e o foreground service + o exercício do Health Services ficariam órfãos.
 * Aqui a UI pode morrer e renascer: o estado, o timer e o callback do Health Services
 * sobrevivem (o foreground service mantém o processo vivo). O [WorkoutViewModel] é só uma
 * fachada que reexpõe estes flows.
 */
object WorkoutSessionHolder {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private lateinit var appContext: Context
    private lateinit var exerciseManager: ExerciseManager
    private lateinit var dataLayer: DataLayerManager
    @Volatile private var initialized = false

    private val _state = MutableStateFlow(WorkoutState.IDLE)
    val state: StateFlow<WorkoutState> = _state.asStateFlow()

    private val _elapsedSeconds = MutableStateFlow(0L)
    val elapsedSeconds: StateFlow<Long> = _elapsedSeconds.asStateFlow()

    val metrics: StateFlow<LiveMetrics> get() = exerciseManager.metrics

    private var timerJob: Job? = null
    private var startEpochMs: Long = 0L

    /** Idempotente. Chamado pela Application e por toda criação de ViewModel. */
    fun ensureInit(context: Context) {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            appContext = context.applicationContext
            exerciseManager = ExerciseManager(appContext)
            dataLayer = DataLayerManager(appContext)
            TrainingPlanRepository.ensureInit(appContext)
            initialized = true
        }
        // Reanexa a uma corrida que sobreviveu à morte da UI / do processo.
        scope.launch {
            if (exerciseManager.restoreIfActive()) {
                startEpochMs = System.currentTimeMillis() - exerciseManager.currentElapsedSeconds() * 1000
                _state.value = WorkoutState.RUNNING
                startTimer()
            }
        }
    }

    fun start() {
        scope.launch {
            startEpochMs = System.currentTimeMillis()
            startService()
            runCatching { exerciseManager.start() }
                .onSuccess {
                    _state.value = WorkoutState.RUNNING
                    startTimer()
                }
                .onFailure {
                    // Permissão negada / falha de sensor: não entra em RUNNING fantasma.
                    stopService()
                    _state.value = WorkoutState.IDLE
                }
        }
    }

    fun togglePause() {
        scope.launch {
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
        // Guarda contra duplo-toque em "Encerrar".
        if (_state.value == WorkoutState.ENDED || _state.value == WorkoutState.IDLE) return
        scope.launch {
            timerJob?.cancel()
            exerciseManager.end()

            // Monta e despacha o payload ANTES de derrubar o foreground service
            // (manter a proteção do processo até o envio).
            val payload = WorkoutPayload.from(
                metrics = metrics.value,
                elapsedTimeSec = exerciseManager.finalElapsedSeconds().toDouble(),
                startDateIso = Instant.ofEpochMilli(startEpochMs).toString(),
                endDateIso = Instant.now().toString(),
                source = "wear_os",
            )
            dataLayer.sendWorkout(payload)

            _state.value = WorkoutState.ENDED
            stopService()
        }
    }

    fun reset() {
        exerciseManager.reset()
        TrainingPlanRepository.clearAlert()
        _elapsedSeconds.value = 0L
        _state.value = WorkoutState.IDLE
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = scope.launch {
            while (isActive) {
                delay(1000)
                _elapsedSeconds.value = exerciseManager.onTick()
                // Alerta de pace por zona (haptic na transição) durante o treino guiado.
                TrainingPlanRepository.evaluatePace(metrics.value.currentPace, _elapsedSeconds.value.toDouble())
                if (_elapsedSeconds.value % 5 == 0L) {
                    val m = metrics.value
                    dataLayer.sendLiveUpdate(m.distanceKm, m.currentPace, m.heartRate, _elapsedSeconds.value)
                }
            }
        }
    }

    private fun startService() {
        appContext.startForegroundService(Intent(appContext, WorkoutService::class.java))
    }

    private fun stopService() {
        appContext.stopService(Intent(appContext, WorkoutService::class.java))
    }
}
