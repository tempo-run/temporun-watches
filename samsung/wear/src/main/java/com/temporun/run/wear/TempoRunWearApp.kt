package com.temporun.run.wear

import android.app.Application
import com.temporun.run.wear.workout.WorkoutSessionHolder

/**
 * Application do app de relógio. Inicializa o [WorkoutSessionHolder] no início do processo,
 * para que uma corrida ativa seja reanexada mesmo se o processo tiver sido morto e reiniciado
 * (antes de qualquer Activity existir).
 */
class TempoRunWearApp : Application() {
    override fun onCreate() {
        super.onCreate()
        WorkoutSessionHolder.ensureInit(this)
    }
}
