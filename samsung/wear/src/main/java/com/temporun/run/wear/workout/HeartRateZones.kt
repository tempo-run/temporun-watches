package com.temporun.run.wear.workout

/**
 * Zonas de FC (modelo de 5 zonas, % do maxHR). Espelha a struct HeartRateZones do Apple Watch.
 */
class HeartRateZones(maxHR: Double) {
    private val z1 = (maxHR * 0.50)..(maxHR * 0.60)  // Recuperação
    private val z2 = (maxHR * 0.60)..(maxHR * 0.70)  // Base aeróbica
    private val z3 = (maxHR * 0.70)..(maxHR * 0.80)  // Tempo
    private val z4 = (maxHR * 0.80)..(maxHR * 0.90)  // Limiar
    private val z5 = (maxHR * 0.90)..(maxHR * 1.00)  // VO₂ máx

    fun zone(hr: Double): Int = when {
        hr in z1 -> 1
        hr in z2 -> 2
        hr in z3 -> 3
        hr in z4 -> 4
        hr in z5 -> 5
        else -> if (hr < z1.start) 0 else 5
    }
}
