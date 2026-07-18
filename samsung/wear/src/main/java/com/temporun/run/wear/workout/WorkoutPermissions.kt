package com.temporun.run.wear.workout

import android.Manifest

/**
 * Permissões runtime pedidas antes de iniciar QUALQUER corrida — todas as portas de entrada
 * (aba "Livre" e aba "Hoje") devem passar por aqui.
 *
 * Motivo: ExerciseManager.start() filtra os DataTypes por permissão concedida (degradação
 * graciosa). Se uma porta inicia sem pedir as permissões, o exercício "inicia com sucesso"
 * sem NENHUM sensor: o cronômetro (local) anda, mas FC/GPS/passos ficam zerados a corrida
 * inteira. Foi exatamente o bug da aba Hoje, que chamava vm.start() direto.
 */
val WORKOUT_PERMISSIONS = arrayOf(
    Manifest.permission.BODY_SENSORS,
    Manifest.permission.ACCESS_FINE_LOCATION,
    Manifest.permission.ACTIVITY_RECOGNITION,
    Manifest.permission.POST_NOTIFICATIONS,
)
