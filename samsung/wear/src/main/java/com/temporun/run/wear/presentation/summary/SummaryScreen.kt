package com.temporun.run.wear.presentation.summary

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.presentation.theme.TempoOrange
import com.temporun.run.wear.util.formattedDistance
import com.temporun.run.wear.util.formattedDuration
import com.temporun.run.wear.util.formattedPace
import com.temporun.run.wear.util.formattedRaceTime
import com.temporun.run.wear.workout.RacePredictions
import com.temporun.run.wear.workout.WorkoutViewModel

/**
 * Resumo pós-corrida (estado ended), por seções. Equivalente ao SummaryView.swift.
 * TODO(Fase 2/5): exibir XP, streak e recordes retornados pela edge function
 *                 watch-workout-save (WatchSaveResult).
 */
@Composable
fun SummaryScreen(vm: WorkoutViewModel) {
    val m by vm.metrics.collectAsStateWithLifecycle()
    val elapsed by vm.elapsedSeconds.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 14.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Corrida salva!", color = TempoOrange, style = MaterialTheme.typography.title3)
        Text("Sincronização com o celular: Fase 2", fontSize = 9.sp, color = Color.Gray)
        Spacer(Modifier.height(6.dp))

        Section("Corrida") {
            SRow("Distância", "${m.distanceKm.formattedDistance()} km", TempoOrange)
            SRow("Tempo", elapsed.formattedDuration())
            SRow("Pace médio", "${m.averagePace.formattedPace()}/km")
            SRow("Melhor pace", "${m.bestPace.formattedPace()}/km", TempoOrange)
            SRow("Passos", "${m.stepCount.toInt()}")
            SRow("Cadência", "${m.cadence.toInt()} spm")
        }
        Section("Cardio") {
            SRow("FC média", "${m.averageHeartRate.toInt()} bpm", Color(0xFFEF5350))
            SRow("FC mín", "${m.minHeartRate.toInt()} bpm", Color(0xFF4FC3F7))
            SRow("FC máx", "${m.maxHeartRate.toInt()} bpm", Color(0xFFEF5350))
            if (m.vo2Max > 0) SRow("VO₂ máx", "%.1f ml/kg".format(m.vo2Max), Color(0xFF66BB6A))
        }
        Section("Energia") {
            SRow("Calorias", "${m.activeEnergyBurned.toInt()} kcal", TempoOrange)
        }
        Section("Altitude") {
            SRow("Ganho", "+ ${m.elevationGain.toInt()} m", Color(0xFF66BB6A))
            SRow("Perda", "- ${m.elevationLoss.toInt()} m", Color(0xFFEF5350))
            SRow("Máxima", "${m.maxAltitude.toInt()} m")
        }
        if (m.splits.isNotEmpty()) {
            Section("Splits") {
                val best = m.splits.minOfOrNull { it.paceSec } ?: 0.0
                for (s in m.splits) {
                    SRow(
                        "km ${s.km}", s.paceSec.formattedPace(),
                        if (s.paceSec == best) TempoOrange else Color.White,
                    )
                }
            }
        }
        if (m.vo2Max > 0) {
            val p = RacePredictions.fromVo2Max(m.vo2Max)
            Section("Predição · Daniels") {
                SRow("5 km", p.km5.formattedRaceTime(), TempoOrange)
                SRow("10 km", p.km10.formattedRaceTime())
                SRow("Meia", p.halfMarathon.formattedRaceTime())
                SRow("Maratona", p.marathon.formattedRaceTime())
            }
        }

        Spacer(Modifier.height(8.dp))
        Button(onClick = { vm.reset() }) {
            Text("Nova corrida", fontSize = 12.sp)
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
        Text(title, fontSize = 11.sp, color = TempoOrange)
        content()
    }
}

@Composable
private fun SRow(label: String, value: String, color: Color = Color.White) {
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 1.dp)) {
        Text(label, fontSize = 11.sp, color = Color.Gray)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 11.sp, color = color)
    }
}
