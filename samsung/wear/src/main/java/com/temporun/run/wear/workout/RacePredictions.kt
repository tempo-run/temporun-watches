package com.temporun.run.wear.workout

/**
 * Preditor de provas a partir do VO₂ máx (fórmula de Daniels & Gilbert).
 * Espelha a struct RacePredictions do Apple Watch. Tempos em segundos.
 */
data class RacePredictions(
    val km5: Double = 0.0,
    val km10: Double = 0.0,
    val halfMarathon: Double = 0.0,
    val marathon: Double = 0.0,
) {
    companion object {
        fun fromVo2Max(vo2Max: Double): RacePredictions {
            fun predict(distanceM: Double): Double {
                if (vo2Max <= 0) return 0.0
                val pct = when {
                    distanceM < 5001 -> 0.9757
                    distanceM < 10001 -> 0.9442
                    distanceM < 21098 -> 0.8942
                    else -> 0.8397
                }
                val targetVo2 = vo2Max * pct
                val velocity = (targetVo2 + 3.5) / 0.2  // m/min
                return (distanceM / velocity) * 60
            }
            return RacePredictions(
                km5 = predict(5000.0),
                km10 = predict(10000.0),
                halfMarathon = predict(21097.5),
                marathon = predict(42195.0),
            )
        }
    }
}
