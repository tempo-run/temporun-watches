package com.temporun.run.wear.workout

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.SystemClock
import androidx.concurrent.futures.await
import androidx.core.content.ContextCompat
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Núcleo de captura da corrida via Health Services (`ExerciseClient`). Equivalente Android do
 * WorkoutManager.swift (HKWorkoutSession + HKLiveWorkoutBuilder).
 *
 * Decisões de robustez (revisão Fase 1):
 * - A duração autoritativa vem do `activeDurationCheckpoint` do Health Services (desconta
 *   pausas e sobrevive à suspensão do processo com a tela apagada); o tick de 1 s só
 *   interpola visualmente, ancorado em `SystemClock.elapsedRealtime()`.
 * - `start()` filtra os DataTypes tanto por capacidade do device quanto por PERMISSÃO
 *   concedida → degradação graciosa real (corrida indoor sem GPS, ou sem FC).
 *
 * Métricas que o Health Services 1.0.0 NÃO expõe (biomecânica avançada: potência, passada,
 * contato com o solo, oscilação vertical) ficam ausentes — o payload as OMITE para virarem
 * NULL no banco (não 0). Ver CONTRACT_AUDIT.md.
 */
class ExerciseManager(context: Context) {

    private val appContext = context.applicationContext
    private val exerciseClient: ExerciseClient =
        HealthServices.getClient(appContext).exerciseClient

    private val haptics = Haptics(appContext)
    private val splitTracker = SplitTracker()

    // TODO(Fase 3): receber maxHR real do perfil do usuário via Data Layer.
    private var hrZones = HeartRateZones(maxHR = 190.0)

    private val _metrics = MutableStateFlow(LiveMetrics())
    val metrics: StateFlow<LiveMetrics> = _metrics.asStateFlow()

    // ── Duração ancorada no checkpoint do Health Services ────────────────────
    private data class DurationAnchor(val activeMs: Long, val anchorRealtimeMs: Long)
    private var anchor: DurationAnchor? = null
    private var lastElapsedSec: Long = 0
    private var altitudeSeen = false

    // Teto de sanidade para pace (seg/km): ignora spikes de GPS mais rápidos que 2:00/km.
    private val minPlausiblePaceSec = 120.0

    /** Métricas desejadas (paridade com o Apple Watch). Filtradas por capacidade + permissão. */
    private val desiredDataTypes: Set<DataType<*, *>> = setOf(
        DataType.HEART_RATE_BPM,
        DataType.HEART_RATE_BPM_STATS,
        DataType.DISTANCE_TOTAL,
        DataType.SPEED,
        DataType.STEPS_TOTAL,
        DataType.STEPS_PER_MINUTE,
        DataType.CALORIES_TOTAL,
        DataType.ABSOLUTE_ELEVATION,
        DataType.VO2_MAX,
        DataType.LOCATION,
    )

    // Mapa DataType → permissão runtime exigida.
    private fun permissionFor(dt: DataType<*, *>): String? = when (dt) {
        DataType.HEART_RATE_BPM, DataType.HEART_RATE_BPM_STATS, DataType.VO2_MAX ->
            Manifest.permission.BODY_SENSORS
        DataType.LOCATION, DataType.ABSOLUTE_ELEVATION ->
            Manifest.permission.ACCESS_FINE_LOCATION
        DataType.STEPS_TOTAL, DataType.STEPS_PER_MINUTE ->
            Manifest.permission.ACTIVITY_RECOGNITION
        else -> null // DISTANCE_TOTAL, SPEED, CALORIES_TOTAL: derivadas, sem permissão dedicada
    }

    private fun granted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(appContext, permission) == PackageManager.PERMISSION_GRANTED

    private val updateCallback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) = consume(update)
        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {}
        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {}
        override fun onRegistered() {}
        override fun onRegistrationFailed(throwable: Throwable) {}
    }

    private fun consume(update: ExerciseUpdate) {
        // Re-ancora a duração no checkpoint autoritativo a cada update.
        update.activeDurationCheckpoint?.let { cp ->
            val activeMs = cp.activeDuration.toMillis()
            val deltaSinceCheckpoint = System.currentTimeMillis() - cp.time.toEpochMilli()
            anchor = DurationAnchor(
                activeMs = activeMs,
                anchorRealtimeMs = SystemClock.elapsedRealtime() - deltaSinceCheckpoint,
            )
        }

        val c = update.latestMetrics
        var m = _metrics.value

        // ── Cardio ────────────────────────────────────────────────────────────
        c.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value?.let { hr ->
            if (hr > 0) {
                m = m.copy(heartRate = hr, currentZone = hrZones.zone(hr))
                splitTracker.registerHeartRate(hr)
            }
        }
        c.getData(DataType.HEART_RATE_BPM_STATS)?.let { stats ->
            m = m.copy(averageHeartRate = stats.average, minHeartRate = stats.min, maxHeartRate = stats.max)
        }
        c.getData(DataType.VO2_MAX).lastOrNull()?.value?.let { vo2 ->
            if (vo2 > 0) m = m.copy(vo2Max = vo2)
        }

        // ── Corrida ───────────────────────────────────────────────────────────
        c.getData(DataType.DISTANCE_TOTAL)?.total?.let { meters ->
            m = m.copy(distanceKm = meters / 1000.0)
        }
        c.getData(DataType.SPEED).lastOrNull()?.value?.let { mps ->
            m = m.copy(currentSpeed = mps)
            if (mps > 0.3) {
                val pace = 1000.0 / mps // seg/km
                m = m.copy(
                    currentPace = pace,
                    // pace_melhor com teto: ignora leituras implausivelmente rápidas (spike de GPS)
                    bestPace = when {
                        pace < minPlausiblePaceSec -> m.bestPace
                        m.bestPace == 0.0 -> pace
                        else -> minOf(m.bestPace, pace)
                    },
                )
            }
        }
        c.getData(DataType.STEPS_TOTAL)?.total?.let { steps -> m = m.copy(stepCount = steps.toDouble()) }
        c.getData(DataType.STEPS_PER_MINUTE).lastOrNull()?.value?.let { spm ->
            if (spm > 0) m = m.copy(cadence = spm.toDouble())
        }

        // ── Energia ───────────────────────────────────────────────────────────
        c.getData(DataType.CALORIES_TOTAL)?.total?.let { kcal -> m = m.copy(activeEnergyBurned = kcal) }

        // ── Altitude (sentinela explícita, evita colidir com 0 m real) ────────
        c.getData(DataType.ABSOLUTE_ELEVATION).lastOrNull()?.value?.let { alt ->
            if (!altitudeSeen) {
                altitudeSeen = true
                m = m.copy(currentAltitude = alt, maxAltitude = alt, minAltitude = alt)
            } else {
                val diff = alt - m.currentAltitude
                m = m.copy(
                    currentAltitude = alt,
                    maxAltitude = maxOf(m.maxAltitude, alt),
                    minAltitude = minOf(m.minAltitude, alt),
                    elevationGain = m.elevationGain + if (diff > 0) diff else 0.0,
                    elevationLoss = m.elevationLoss + if (diff < 0) -diff else 0.0,
                )
            }
        }

        // ── Splits (haptic ao fechar km) — usa o elapsed autoritativo ─────────
        val elapsedSec = currentElapsedSeconds().toDouble()
        if (splitTracker.checkSplit(m.distanceKm, elapsedSec, m.elevationGain)) haptics.split()
        m = m.copy(splits = splitTracker.splits)

        _metrics.value = m
    }

    /** Elapsed autoritativo (segundos): derivado do checkpoint + relógio monotônico. */
    fun currentElapsedSeconds(): Long {
        val a = anchor ?: return lastElapsedSec
        return (a.activeMs + (SystemClock.elapsedRealtime() - a.anchorRealtimeMs)) / 1000
    }

    /**
     * Tick de 1 s (só durante RUNNING): atualiza elapsed, acumula tempo na zona de FC com o
     * DELTA real (corrige saltos pós-suspensão) e recalcula pace médio.
     * Retorna o elapsed em segundos para a UI.
     */
    fun onTick(): Long {
        val newElapsed = if (anchor != null) currentElapsedSeconds() else lastElapsedSec + 1
        val delta = (newElapsed - lastElapsedSec).coerceAtLeast(0)
        lastElapsedSec = newElapsed
        var m = _metrics.value

        if (m.heartRate > 0 && delta > 0) {
            val zone = hrZones.zone(m.heartRate)
            val zones = m.timeInZone.toMutableList()
            zones[zone] = zones[zone] + delta
            m = m.copy(timeInZone = zones, currentZone = zone)
        }
        if (m.distanceKm > 0 && newElapsed > 0) {
            m = m.copy(averagePace = newElapsed / m.distanceKm)
        }
        if (m.cadence == 0.0 && m.stepCount > 0 && newElapsed > 0) {
            m = m.copy(cadence = m.stepCount / newElapsed * 60.0)
        }
        _metrics.value = m
        return newElapsed
    }

    suspend fun supportedDataTypes(): Set<DataType<*, *>> {
        val caps = exerciseClient.getCapabilitiesAsync().await()
        return caps.getExerciseTypeCapabilities(ExerciseType.RUNNING).supportedDataTypes
    }

    /** Inicia o exercício. Lança se as permissões mínimas faltarem — o chamador deve tratar. */
    suspend fun start() {
        val supported = supportedDataTypes()
        // Capacidade do device E permissão concedida.
        val dataTypes = desiredDataTypes.filterTo(mutableSetOf()) { dt ->
            dt in supported && permissionFor(dt)?.let { granted(it) } != false
        }
        val gpsEnabled = DataType.LOCATION in dataTypes
        val config = ExerciseConfig.builder(ExerciseType.RUNNING)
            .setDataTypes(dataTypes)
            .setIsAutoPauseAndResumeEnabled(false)
            .setIsGpsEnabled(gpsEnabled)
            .build()
        exerciseClient.setUpdateCallback(updateCallback)
        exerciseClient.startExerciseAsync(config).await()
    }

    /**
     * Reanexa o callback a um exercício já em andamento (Activity recriada / processo morto e
     * restaurado). Retorna true se havia exercício deste app ativo. Guia "Restore an exercise".
     */
    suspend fun restoreIfActive(): Boolean {
        val info = runCatching { exerciseClient.getCurrentExerciseInfoAsync().await() }.getOrNull()
            ?: return false
        return if (info.exerciseTrackedStatus == ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS) {
            exerciseClient.setUpdateCallback(updateCallback)
            true
        } else false
    }

    suspend fun pause() = exerciseClient.pauseExerciseAsync().await()
    suspend fun resume() = exerciseClient.resumeExerciseAsync().await()

    suspend fun end() {
        runCatching { exerciseClient.endExerciseAsync().await() }
        runCatching { exerciseClient.clearUpdateCallbackAsync(updateCallback).await() }
    }

    /** Elapsed final (segundos) para o payload — autoritativo, não o último tick. */
    fun finalElapsedSeconds(): Long = currentElapsedSeconds().coerceAtLeast(lastElapsedSec)

    fun reset() {
        splitTracker.reset()
        anchor = null
        lastElapsedSec = 0
        altitudeSeen = false
        _metrics.value = LiveMetrics()
    }
}
