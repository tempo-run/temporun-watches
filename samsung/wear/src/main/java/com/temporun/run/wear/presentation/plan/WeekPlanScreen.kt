package com.temporun.run.wear.presentation.plan

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.presentation.theme.TempoOrange
import com.temporun.run.wear.training.TrainingPlanRepository

/**
 * Semana de treino (aba "Semana"). Equivalente ao WeekPlanView.swift. Destaca o dia atual.
 */
@Composable
fun WeekPlanScreen() {
    val week by TrainingPlanRepository.weekWorkouts.collectAsStateWithLifecycle()
    val today by TrainingPlanRepository.todayWorkout.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 10.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Semana", style = MaterialTheme.typography.caption1, color = Color.Gray)
        Spacer(Modifier.height(4.dp))

        if (week.isEmpty()) {
            Text(
                "Sem plano sincronizado",
                style = MaterialTheme.typography.caption2,
                color = Color.Gray,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 12.dp),
            )
            return@Column
        }

        for (d in week) {
            val isToday = d.dia == today?.dia
            Row(
                modifier = Modifier.fillMaxWidth()
                    .padding(vertical = 2.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isToday) TempoOrange.copy(alpha = 0.18f) else Color.Transparent)
                    .padding(horizontal = 6.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(7.dp).clip(CircleShape).background(intensityColor(d)))
                Spacer(Modifier.width(6.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        d.dia.take(3),
                        fontSize = 11.sp,
                        color = if (isToday) TempoOrange else Color.White,
                    )
                    Text(d.tipo, fontSize = 9.sp, color = Color.Gray)
                }
                Text(
                    if (d.workoutType.isRest) "—" else "${trimKm(d.distanciaKm)}km",
                    fontSize = 11.sp,
                    color = Color.White,
                )
            }
        }
    }
}
