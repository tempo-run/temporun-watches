package com.temporun.run.wear.workout

import android.content.Context
import androidx.concurrent.futures.await
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Núcleo de captura da corrida via Health Services (`ExerciseClient`). Equivalente Android do
 * WorkoutManager.swift (HKWorkoutSession + HKLiveWorkoutBuilder).
 *
 * Fase 0: estrutura, aquisição do client, checagem de capacidades, callback registrado e
 * extração das métricas básicas (FC, distância, velocidade, passos, calorias).
 * TODO(Fase 1): biomecânica, elevação/GPS, zonas de FC, splits + haptic, VO₂/predições.
 */
class ExerciseManager(context: Context) {

    private val exerciseClient: ExerciseClient =
        HealthServices.getClient(context.applicationContext).exerciseClient

    private val _metrics = MutableStateFlow(LiveMetrics())
    val metrics: StateFlow<LiveMetrics> = _metrics.asStateFlow()

    /** Métricas desejadas (paridade com o Apple Watch). Filtradas por [supportedDataTypes]. */
    private val desiredDataTypes: Set<DataType<*, *>> = setOf(
        DataType.HEART_RATE_BPM,
        DataType.DISTANCE_TOTAL,
        DataType.SPEED,
        DataType.STEPS_TOTAL,
        DataType.CALORIES_TOTAL,
        DataType.LOCATION,
    )

    private val updateCallback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val c = update.latestMetrics
            val hr = c.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value
            val distanceMeters = c.getData(DataType.DISTANCE_TOTAL)?.total?.toDouble()
            val speed = c.getData(DataType.SPEED).lastOrNull()?.value
            val steps = c.getData(DataType.STEPS_TOTAL)?.total?.toDouble()
            val calories = c.getData(DataType.CALORIES_TOTAL)?.total?.toDouble()

            _metrics.value = _metrics.value.copy(
                heartRate = hr ?: _metrics.value.heartRate,
                distanceKm = distanceMeters?.div(1000.0) ?: _metrics.value.distanceKm,
                currentSpeed = speed ?: _metrics.value.currentSpeed,
                stepCount = steps ?: _metrics.value.stepCount,
                activeEnergyBurned = calories ?: _metrics.value.activeEnergyBurned,
            )
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {}
        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {}
        override fun onRegistered() {}
        override fun onRegistrationFailed(throwable: Throwable) {}
    }

    /** Tipos de dado que ESTE relógio realmente suporta para corrida. */
    suspend fun supportedDataTypes(): Set<DataType<*, *>> {
        val caps = exerciseClient.getCapabilitiesAsync().await()
        return caps.getExerciseTypeCapabilities(ExerciseType.RUNNING).supportedDataTypes
    }

    suspend fun start() {
        val supported = supportedDataTypes()
        val dataTypes = desiredDataTypes.filterTo(mutableSetOf()) { it in supported }
        val config = ExerciseConfig.builder(ExerciseType.RUNNING)
            .setDataTypes(dataTypes)
            .setIsAutoPauseAndResumeEnabled(false)
            .setIsGpsEnabled(DataType.LOCATION in supported)
            .build()
        exerciseClient.setUpdateCallback(updateCallback)
        exerciseClient.startExerciseAsync(config).await()
    }

    suspend fun pause() = exerciseClient.pauseExerciseAsync().await()
    suspend fun resume() = exerciseClient.resumeExerciseAsync().await()
    suspend fun end() = exerciseClient.endExerciseAsync().await()

    fun reset() { _metrics.value = LiveMetrics() }
}
