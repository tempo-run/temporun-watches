package com.temporun.run.wear.workout

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Padrões de vibração do app. Equivalente aos haptics do Apple Watch
 * (WKInterfaceDevice.play): split → .success, pace fora da zona → .directionUp/Down.
 */
class Haptics(context: Context) {

    private val vibrator: Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val mgr = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            mgr.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    /** Split de km fechado (↔ .success). */
    fun split() = vibrate(longArrayOf(0, 120, 80, 120))

    /** Pace rápido demais (↔ .directionUp). Usado na Fase 3. */
    fun paceTooFast() = vibrate(longArrayOf(0, 80, 60, 80, 60, 200))

    /** Pace lento demais (↔ .directionDown). Usado na Fase 3. */
    fun paceTooSlow() = vibrate(longArrayOf(0, 200, 60, 80, 60, 80))

    private fun vibrate(pattern: LongArray) {
        runCatching { vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1)) }
    }
}
