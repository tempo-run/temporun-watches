package com.temporun.run.wear.presentation.start

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.workout.WorkoutViewModel

/**
 * Tela inicial (estado idle). Equivalente ao StartView.swift / aba "Livre".
 * TODO(Fase 3): adicionar abas Hoje / Semana / Status (HorizontalPager).
 */
@Composable
fun StartScreen(vm: WorkoutViewModel) {
    Column(
        modifier = Modifier.fillMaxSize().padding(8.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "TempoRun",
            color = MaterialTheme.colors.primary,
            style = MaterialTheme.typography.title2,
        )
        Text(
            text = "Corrida do pulso",
            style = MaterialTheme.typography.caption2,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(bottom = 12.dp),
        )
        Button(onClick = { vm.start() }) {
            Text("Iniciar")
        }
    }
}
