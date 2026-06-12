package com.temporun.run.wear

import android.app.Application
import com.temporun.run.wear.network.NetworkMonitor
import com.temporun.run.wear.network.OfflineQueue
import com.temporun.run.wear.training.TrainingPlanRepository
import com.temporun.run.wear.workout.WorkoutSessionHolder

/**
 * Application do app de relógio. Inicializa os singletons no início do processo:
 * - [WorkoutSessionHolder]: reanexa uma corrida ativa após morte/restart do processo.
 * - [TrainingPlanRepository]: carrega o plano em cache.
 * - [OfflineQueue] / [NetworkMonitor]: fila standalone + sync automático quando a rede volta.
 */
class TempoRunWearApp : Application() {
    override fun onCreate() {
        super.onCreate()
        WorkoutSessionHolder.ensureInit(this)
        TrainingPlanRepository.ensureInit(this)
        OfflineQueue.ensureInit(this)
        NetworkMonitor.ensureInit(this)
    }
}
