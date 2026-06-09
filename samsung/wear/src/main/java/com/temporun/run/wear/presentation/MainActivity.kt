package com.temporun.run.wear.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.TimeText
import com.temporun.run.wear.presentation.live.LiveMetricsPager
import com.temporun.run.wear.presentation.start.StartScreen
import com.temporun.run.wear.presentation.summary.SummaryScreen
import com.temporun.run.wear.presentation.theme.TempoRunWearTheme
import com.temporun.run.wear.workout.WorkoutState
import com.temporun.run.wear.workout.WorkoutViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            TempoRunWearTheme {
                TempoRunApp()
            }
        }
    }
}

/**
 * Raiz da navegação por estado da corrida. Espelha ContentView.swift:
 * idle → telas iniciais · running/paused → métricas ao vivo · ended → resumo.
 */
@Composable
fun TempoRunApp(vm: WorkoutViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    Scaffold(timeText = { TimeText() }) {
        when (state) {
            WorkoutState.IDLE -> StartScreen(vm)
            WorkoutState.RUNNING, WorkoutState.PAUSED -> LiveMetricsPager(vm)
            WorkoutState.ENDED -> SummaryScreen(vm)
        }
    }
}
