package com.temporun.run.wear.connectivity

import com.temporun.run.wear.workout.KmSplit
import com.temporun.run.wear.workout.LiveMetrics
import kotlinx.serialization.Serializable

/**
 * Payload de transporte da corrida. Espelha WorkoutPayload/SplitPayload (Codable) do Apple
 * Watch. Serializado com kotlinx.serialization para trafegar pelo Wearable Data Layer (Fase 2)
 * e para o cliente standalone (Fase 5).
 *
 * Os nomes aqui são camelCase (transporte interno). A conversão para o schema da tabela
 * `corridas` (snake_case, esperado pela edge function watch-workout-save) é feita em
 * [toSupabaseMap]. Ver samsung/DECISIONS.md (D1, D2).
 */
@Serializable
data class SplitPayload(
    val km: Int,
    val durationSec: Double,
    val paceSec: Double,
    val avgHeartRate: Double,
    val elevationGain: Double,
) {
    constructor(s: KmSplit) : this(s.km, s.durationSec, s.paceSec, s.avgHeartRate, s.elevationGain)
}

@Serializable
data class WorkoutPayload(
    val distanceKm: Double,
    val elapsedTimeSec: Double,
    val averagePace: Double,
    val bestPace: Double,
    val currentSpeed: Double,
    val stepCount: Double,
    val cadence: Double,
    val strideLength: Double,
    val runningPower: Double,
    val groundContactTime: Double,
    val verticalOscillation: Double,
    val verticalRatio: Double,
    val averageHeartRate: Double,
    val minHeartRate: Double,
    val maxHeartRate: Double,
    val vo2Max: Double,
    val timeInZone: List<Double>,
    val activeEnergyBurned: Double,
    val basalEnergyBurned: Double,
    val elevationGain: Double,
    val elevationLoss: Double,
    val maxAltitude: Double,
    val minAltitude: Double,
    val splits: List<SplitPayload>,
    val startDateIso: String,
    val endDateIso: String,
    /** "wear_os" (recebido pelo celular) ou "wear_os_standalone". Ver DECISIONS.md (D2). */
    val source: String,
) {
    companion object {
        fun from(
            metrics: LiveMetrics,
            elapsedTimeSec: Double,
            startDateIso: String,
            endDateIso: String,
            source: String,
        ) = WorkoutPayload(
            distanceKm = metrics.distanceKm,
            elapsedTimeSec = elapsedTimeSec,
            averagePace = metrics.averagePace,
            bestPace = metrics.bestPace,
            currentSpeed = metrics.currentSpeed,
            stepCount = metrics.stepCount,
            cadence = metrics.cadence,
            strideLength = metrics.strideLength,
            runningPower = metrics.runningPower,
            groundContactTime = metrics.groundContactTime,
            verticalOscillation = metrics.verticalOscillation,
            verticalRatio = metrics.verticalRatio,
            averageHeartRate = metrics.averageHeartRate,
            minHeartRate = metrics.minHeartRate,
            maxHeartRate = metrics.maxHeartRate,
            vo2Max = metrics.vo2Max,
            timeInZone = metrics.timeInZone,
            activeEnergyBurned = metrics.activeEnergyBurned,
            basalEnergyBurned = metrics.basalEnergyBurned,
            elevationGain = metrics.elevationGain,
            elevationLoss = metrics.elevationLoss,
            maxAltitude = metrics.maxAltitude,
            minAltitude = metrics.minAltitude,
            splits = metrics.splits.map { SplitPayload(it) },
            startDateIso = startDateIso,
            endDateIso = endDateIso,
            source = source,
        )
    }

    /**
     * Converte para o dicionário no schema da tabela `corridas`, com os nomes EXATOS
     * que a edge function watch-workout-save espera (ver WEAR_OS_PLAN.md §1.3).
     */
    fun toSupabaseMap(): Map<String, Any?> = mapOf(
        "distancia_km" to distanceKm,
        "duracao_seg" to elapsedTimeSec.toInt(),
        "pace_medio" to averagePace,
        "pace_melhor" to bestPace,
        "velocidade_media" to currentSpeed,
        "step_count" to stepCount.toInt(),
        "cadencia" to cadence,
        "stride_length" to strideLength,
        "running_power" to runningPower,
        "ground_contact" to groundContactTime,
        "vertical_osc" to verticalOscillation,
        "vertical_ratio" to verticalRatio,
        "bpm_medio" to averageHeartRate,
        "fc_min" to minHeartRate,
        "fc_max" to maxHeartRate,
        "vo2_estimado" to vo2Max,
        "tempo_zona1" to timeInZone.getOrElse(1) { 0.0 },
        "tempo_zona2" to timeInZone.getOrElse(2) { 0.0 },
        "tempo_zona3" to timeInZone.getOrElse(3) { 0.0 },
        "tempo_zona4" to timeInZone.getOrElse(4) { 0.0 },
        "tempo_zona5" to timeInZone.getOrElse(5) { 0.0 },
        "calorias_ativas" to activeEnergyBurned,
        "calorias_basais" to basalEnergyBurned,
        "calorias_total" to (activeEnergyBurned + basalEnergyBurned),
        "ganho_elevacao" to elevationGain,
        "perda_elevacao" to elevationLoss,
        "altitude_max" to maxAltitude,
        "altitude_min" to minAltitude,
        "splits" to splits.map {
            mapOf(
                "km" to it.km, "duracao" to it.durationSec, "pace" to it.paceSec,
                "fc_media" to it.avgHeartRate, "ganho_elevacao" to it.elevationGain,
            )
        },
        "data_inicio" to startDateIso,
        "data_fim" to endDateIso,
        "source" to source,
        "device" to source,
    )
}
