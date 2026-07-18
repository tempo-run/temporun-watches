package com.temporun.run.wear.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.PageIndicatorState
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.TimeText
import com.temporun.run.wear.presentation.live.LiveMetricsPager
import com.temporun.run.wear.presentation.plan.PaceAlertOverlay
import com.temporun.run.wear.presentation.plan.TodayWorkoutScreen
import com.temporun.run.wear.presentation.plan.WeekPlanScreen
import com.temporun.run.wear.presentation.start.StartScreen
import com.temporun.run.wear.presentation.status.StandaloneStatusScreen
import com.temporun.run.wear.presentation.summary.SummaryScreen
import com.temporun.run.wear.presentation.theme.TempoRunWearTheme
import com.temporun.run.wear.training.TrainingPlanRepository
import com.temporun.run.wear.workout.WORKOUT_PERMISSIONS
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
 * - idle: 4 abas (Hoje / Semana / Livre / Status)
 * - running/paused: métricas ao vivo + overlay de alerta de pace
 * - ended: resumo
 */
@Composable
fun TempoRunApp(vm: WorkoutViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    val paceAlert by TrainingPlanRepository.paceAlert.collectAsStateWithLifecycle()

    Scaffold(timeText = { if (state == WorkoutState.IDLE) TimeText() }) {
        Box(Modifier.fillMaxSize()) {
            when (state) {
                WorkoutState.IDLE -> IdleTabs(vm)
                WorkoutState.RUNNING, WorkoutState.PAUSED -> LiveMetricsPager(vm)
                WorkoutState.ENDED -> SummaryScreen(vm)
            }
            // Overlay de alerta de pace — só durante a corrida.
            if (state == WorkoutState.RUNNING) {
                paceAlert?.let { alert ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
                        PaceAlertOverlay(alert.status, alert.paceAlvo)
                    }
                }
            }
        }
    }
}

@Composable
private fun IdleTabs(vm: WorkoutViewModel) {
    // TODA porta de entrada da corrida pede as permissões antes de iniciar (concessão
    // parcial inicia mesmo assim — degradação graciosa). Sem isso, o Health Services
    // filtra todos os sensores e a corrida roda zerada (FC/GPS/passos em 0).
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { vm.start() }

    val pagerState = rememberPagerState { 4 }
    val indicatorState = object : PageIndicatorState {
        override val pageOffset: Float get() = pagerState.currentPageOffsetFraction
        override val selectedPage: Int get() = pagerState.currentPage
        override val pageCount: Int get() = pagerState.pageCount
    }
    Box(Modifier.fillMaxSize()) {
        HorizontalPager(state = pagerState) { page ->
            when (page) {
                0 -> TodayWorkoutScreen(onStart = { permissionLauncher.launch(WORKOUT_PERMISSIONS) })
                1 -> WeekPlanScreen()
                2 -> StartScreen(vm)
                else -> StandaloneStatusScreen()
            }
        }
        HorizontalPageIndicator(
            pageIndicatorState = indicatorState,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}
