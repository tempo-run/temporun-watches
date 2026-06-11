package com.temporun.run.wear.presentation.plan

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.presentation.theme.TempoOrange
import com.temporun.run.wear.training.DailyWorkout
import com.temporun.run.wear.training.TrainingPlanRepository
import com.temporun.run.wear.training.WorkoutIntensity

/**
 * Treino do dia (aba "Hoje"). Equivalente ao TodayWorkoutView.swift. Lê o plano recebido do
 * celular via Data Layer (TrainingPlanRepository).
 */
@Composable
fun TodayWorkoutScreen(onStart: () -> Unit) {
    val today by TrainingPlanRepository.todayWorkout.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Hoje", style = MaterialTheme.typography.caption1, color = Color.Gray)

        val w = today
        if (w == null) {
            Spacer(Modifier.height(16.dp))
            Text(
                "Nenhum plano sincronizado.\nAbra o TempoRun no celular.",
                style = MaterialTheme.typography.caption2,
                color = Color.Gray,
                textAlign = TextAlign.Center,
            )
            return@Column
        }

        Text(w.tipo, style = MaterialTheme.typography.title3, color = intensityColor(w))
        Spacer(Modifier.height(4.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Metric("${trimKm(w.distanciaKm)} km", "distância")
            if (w.paceAlvo.isNotBlank()) Metric(w.paceAlvo.replace("/km", ""), "alvo")
        }
        if (w.descricao.isNotBlank()) {
            Spacer(Modifier.height(6.dp))
            Text(w.descricao, fontSize = 11.sp, color = Color.White, textAlign = TextAlign.Center)
        }
        if (w.detalheTreino.isNotBlank()) {
            Spacer(Modifier.height(4.dp))
            Text(w.detalheTreino, fontSize = 10.sp, color = Color.Gray, textAlign = TextAlign.Center)
        }
        if (w.alertaLesao.isNotBlank()) {
            Spacer(Modifier.height(4.dp))
            Text("⚠ ${w.alertaLesao}", fontSize = 10.sp, color = TempoOrange, textAlign = TextAlign.Center)
        }

        Spacer(Modifier.height(10.dp))
        if (!w.workoutType.isRest) {
            Button(onClick = onStart) { Text("Iniciar treino", fontSize = 12.sp) }
        } else {
            Text("Dia de descanso 💤", fontSize = 11.sp, color = Color.Gray)
        }
    }
}

@Composable
private fun Metric(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.title3, color = TempoOrange)
        Text(label, fontSize = 9.sp, color = Color.Gray)
    }
}

internal fun intensityColor(w: DailyWorkout): Color = when (w.workoutType.intensity) {
    WorkoutIntensity.REST -> Color(0xFF9E9E9E)
    WorkoutIntensity.EASY -> Color(0xFF66BB6A)
    WorkoutIntensity.MODERATE -> Color(0xFFFFEE58)
    WorkoutIntensity.HARD -> TempoOrange
}

internal fun trimKm(km: Double): String =
    if (km % 1.0 == 0.0) km.toInt().toString() else "%.1f".format(km)
