package com.temporun.run.wear.presentation.live

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.util.formattedDistance
import com.temporun.run.wear.util.formattedDuration
import com.temporun.run.wear.util.formattedPace
import com.temporun.run.wear.workout.WorkoutState
import com.temporun.run.wear.workout.WorkoutViewModel

/**
 * Tela ao vivo (estados running/paused). Equivalente ao LiveMetricsView.swift.
 * Fase 0: página única com as métricas primárias + controles.
 * TODO(Fase 1): HorizontalPager de 8 páginas (Primárias, Biomecânica, Energia, Cardio,
 *               Altitude, Splits, Predições, Controles).
 */
@Composable
fun LiveMetricsPager(vm: WorkoutViewModel) {
    val metrics by vm.metrics.collectAsStateWithLifecycle()
    val elapsed by vm.elapsedSeconds.collectAsStateWithLifecycle()
    val state by vm.state.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = elapsed.formattedDuration(),
            style = MaterialTheme.typography.display2,
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            MetricCell(value = metrics.distanceKm.formattedDistance(), unit = "km")
            MetricCell(value = metrics.currentPace.formattedPace(), unit = "/km")
        }
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            MetricCell(value = "${metrics.heartRate.toInt()}", unit = "bpm")
            MetricCell(value = "${metrics.cadence.toInt()}", unit = "spm")
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Button(
                onClick = { vm.togglePause() },
                colors = ButtonDefaults.secondaryButtonColors(),
            ) {
                Text(if (state == WorkoutState.PAUSED) "▶" else "⏸")
            }
            Button(
                onClick = { vm.end() },
                colors = ButtonDefaults.primaryButtonColors(),
            ) {
                Text("⏹")
            }
        }
    }
}

@Composable
private fun MetricCell(value: String, unit: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.title3)
        Text(unit, style = MaterialTheme.typography.caption2, color = Color(0xFF9E9E9E))
    }
}
