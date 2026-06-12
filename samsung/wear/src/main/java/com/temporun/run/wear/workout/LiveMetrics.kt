package com.temporun.run.wear.workout

/**
 * Modelo de métricas ao vivo da corrida. Espelha a struct LiveMetrics do app Apple Watch
 * (apple/.../WorkoutManager.swift). Nem todo campo é preenchido em todo relógio — depende
 * das capacidades do device (ver ExerciseManager.getSupportedDataTypes na Fase 1).
 */
data class LiveMetrics(
    // ── Corrida ───────────────────────────────────────────────────────────────
    val distanceKm: Double = 0.0,
    val currentPace: Double = 0.0,        // seg/km (instantâneo)
    val averagePace: Double = 0.0,        // seg/km
    val bestPace: Double = 0.0,           // seg/km (menor = mais rápido)
    val currentSpeed: Double = 0.0,       // m/s
    val stepCount: Double = 0.0,
    val cadence: Double = 0.0,            // passos/min

    // ── Biomecânica (Running Dynamics) — device-dependente ─────────────────────
    val strideLength: Double = 0.0,       // m
    val runningPower: Double = 0.0,       // W
    val groundContactTime: Double = 0.0,  // ms
    val verticalOscillation: Double = 0.0,// cm
    val verticalRatio: Double = 0.0,      // %

    // ── Energia ────────────────────────────────────────────────────────────────
    val activeEnergyBurned: Double = 0.0, // kcal
    val basalEnergyBurned: Double = 0.0,  // kcal

    // ── Cardio ─────────────────────────────────────────────────────────────────
    val heartRate: Double = 0.0,          // bpm
    val averageHeartRate: Double = 0.0,   // bpm
    val minHeartRate: Double = 0.0,       // bpm
    val maxHeartRate: Double = 0.0,       // bpm
    val vo2Max: Double = 0.0,             // ml/kg/min (leitura prévia)

    // Zonas de FC: segundos acumulados por zona [Z0..Z5]
    val timeInZone: List<Double> = listOf(0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    val currentZone: Int = 0,

    // ── Altitude / GPS ─────────────────────────────────────────────────────────
    val elevationGain: Double = 0.0,      // m acumulado
    val elevationLoss: Double = 0.0,      // m acumulado
    val currentAltitude: Double = 0.0,    // m
    val maxAltitude: Double = 0.0,        // m
    val minAltitude: Double = 0.0,        // m

    // ── Splits ─────────────────────────────────────────────────────────────────
    val splits: List<KmSplit> = emptyList(),
) {
    val totalEnergyBurned: Double get() = activeEnergyBurned + basalEnergyBurned
}
