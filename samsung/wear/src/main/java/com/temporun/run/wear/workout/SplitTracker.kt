package com.temporun.run.wear.workout

/** Split de 1 km. Espelha a struct KmSplit do Apple Watch. */
data class KmSplit(
    val km: Int,
    val durationSec: Double,
    val paceSec: Double,        // seg/km
    val avgHeartRate: Double,
    val elevationGain: Double,
)

/**
 * Acumula splits por km durante a corrida. Lógica portada de WorkoutManager.checkSplit().
 * O disparo de haptic por split fica na camada de UI/serviço (Fase 1).
 */
class SplitTracker {
    private val _splits = mutableListOf<KmSplit>()
    val splits: List<KmSplit> get() = _splits.toList()

    private var lastSplitKm = 0
    private var splitStartTimeSec = 0.0
    private var splitStartHrSum = 0.0
    private var splitHrSamples = 0
    private var splitStartElevation = 0.0

    fun registerHeartRate(hr: Double) {
        if (hr > 0) { splitStartHrSum += hr; splitHrSamples++ }
    }

    /** Retorna true se um novo split foi fechado (para disparar haptic). */
    fun checkSplit(distanceKm: Double, elapsedTimeSec: Double, elevationGain: Double): Boolean {
        val currentKm = distanceKm.toInt()
        if (currentKm <= lastSplitKm || distanceKm < 1.0) return false

        val splitDuration = elapsedTimeSec - splitStartTimeSec
        val avgHr = if (splitHrSamples > 0) splitStartHrSum / splitHrSamples else 0.0
        _splits.add(
            KmSplit(
                km = currentKm,
                durationSec = splitDuration,
                paceSec = splitDuration, // 1 km exato → pace = duração
                avgHeartRate = avgHr,
                elevationGain = elevationGain - splitStartElevation,
            )
        )
        splitStartTimeSec = elapsedTimeSec
        splitStartHrSum = 0.0
        splitHrSamples = 0
        splitStartElevation = elevationGain
        lastSplitKm = currentKm
        return true
    }

    fun reset() {
        _splits.clear()
        lastSplitKm = 0
        splitStartTimeSec = 0.0
        splitStartHrSum = 0.0
        splitHrSamples = 0
        splitStartElevation = 0.0
    }
}
