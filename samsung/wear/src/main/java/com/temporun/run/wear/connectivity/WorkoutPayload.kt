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
     *
     * A biomecânica avançada (passada, potência, contato com o solo, oscilação vertical) é
     * OMITIDA quando o Health Services não a forneceu — assim a coluna fica NULL no banco,
     * em vez de receber 0 e mascarar "sem dado" como "valor zero". Ver CONTRACT_AUDIT.md.
     */
    fun toSupabaseMap(): Map<String, Any?> = buildMap {
        put("distancia_km", distanceKm)
        put("duracao_seg", elapsedTimeSec.toInt())
        put("pace_medio", averagePace)
        put("pace_melhor", bestPace)
        // velocidade MÉDIA real (m/s), não a instantânea do fim da corrida.
        put("velocidade_media", if (elapsedTimeSec > 0) distanceKm * 1000.0 / elapsedTimeSec else 0.0)
        put("step_count", stepCount.toInt())
        put("cadencia", cadence)
        // Biomecânica: só envia se houver dado (>0), senão omite → NULL.
        if (strideLength > 0) put("stride_length", strideLength)
        if (runningPower > 0) put("running_power", runningPower)
        if (groundContactTime > 0) put("ground_contact", groundContactTime)
        if (verticalOscillation > 0) put("vertical_osc", verticalOscillation)
        if (verticalRatio > 0) put("vertical_ratio", verticalRatio)
        put("bpm_medio", averageHeartRate)
        put("fc_min", minHeartRate)
        put("fc_max", maxHeartRate)
        if (vo2Max > 0) put("vo2_estimado", vo2Max)
        put("tempo_zona1", timeInZone.getOrElse(1) { 0.0 })
        put("tempo_zona2", timeInZone.getOrElse(2) { 0.0 })
        put("tempo_zona3", timeInZone.getOrElse(3) { 0.0 })
        put("tempo_zona4", timeInZone.getOrElse(4) { 0.0 })
        put("tempo_zona5", timeInZone.getOrElse(5) { 0.0 })
        put("calorias_ativas", activeEnergyBurned)
        put("calorias_basais", basalEnergyBurned)
        put("calorias_total", activeEnergyBurned + basalEnergyBurned)
        put("ganho_elevacao", elevationGain)
        put("perda_elevacao", elevationLoss)
        put("altitude_max", maxAltitude)
        put("altitude_min", minAltitude)
        put("splits", splits.map {
            mapOf(
                "km" to it.km, "duracao" to it.durationSec, "pace" to it.paceSec,
                "fc_media" to it.avgHeartRate, "ganho_elevacao" to it.elevationGain,
            )
        })
        put("data_inicio", startDateIso)
        put("data_fim", endDateIso)
        put("source", source)
        put("device", source)
    }
}
