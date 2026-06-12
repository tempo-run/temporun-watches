package com.temporun.run.wear.util

import java.util.Locale

/** Formatadores de pace/duração/distância. Espelham Extensions.swift do Apple Watch. */

/** Pace em seg/km → "m:ss". */
fun Double.formattedPace(): String {
    if (this <= 0 || this.isInfinite() || this.isNaN()) return "--:--"
    val m = (this / 60).toInt()
    val s = (this % 60).toInt()
    return String.format(Locale.US, "%d:%02d", m, s)
}

/** Duração em segundos → "h:mm:ss" ou "m:ss". */
fun Double.formattedDuration(): String {
    val total = this.toInt()
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s)
    else String.format(Locale.US, "%d:%02d", m, s)
}

fun Long.formattedDuration(): String = this.toDouble().formattedDuration()

/** Distância em km → "0.00". */
fun Double.formattedDistance(): String = String.format(Locale.US, "%.2f", this)

/** Tempo de prova (segundos) → "h:mm:ss". */
fun Double.formattedRaceTime(): String {
    val total = this.toInt()
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return String.format(Locale.US, "%d:%02d:%02d", h, m, s)
}
