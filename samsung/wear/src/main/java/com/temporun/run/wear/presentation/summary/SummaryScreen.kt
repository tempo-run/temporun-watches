package com.temporun.run.wear.presentation.summary

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.util.formattedDistance
import com.temporun.run.wear.util.formattedDuration
import com.temporun.run.wear.util.formattedPace
import com.temporun.run.wear.workout.WorkoutViewModel

/**
 * Resumo pós-corrida (estado ended). Equivalente ao SummaryView.swift.
 * TODO(Fase 1/2): seções completas + XP/streak/recordes vindos da edge function.
 */
@Composable
fun SummaryScreen(vm: WorkoutViewModel) {
    val metrics by vm.metrics.collectAsStateWithLifecycle()
    val elapsed by vm.elapsedSeconds.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.fillMaxSize().padding(8.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Corrida salva!", color = MaterialTheme.colors.primary, style = MaterialTheme.typography.title3)
        Text("${metrics.distanceKm.formattedDistance()} km", style = MaterialTheme.typography.title2)
        Text(elapsed.formattedDuration(), style = MaterialTheme.typography.body1)
        Text("${metrics.averagePace.formattedPace()}/km", style = MaterialTheme.typography.caption1)
        Button(
            onClick = { vm.reset() },
            modifier = Modifier.padding(top = 8.dp),
        ) {
            Text("Nova corrida")
        }
    }
}
