package com.temporun.run.wear.presentation.live

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.background
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PageIndicatorState
import androidx.wear.compose.material.Text
import com.temporun.run.wear.presentation.theme.SystemBlue
import com.temporun.run.wear.presentation.theme.SystemGray
import com.temporun.run.wear.presentation.theme.SystemGreen
import com.temporun.run.wear.presentation.theme.SystemRed
import com.temporun.run.wear.presentation.theme.SystemYellow
import com.temporun.run.wear.presentation.theme.TempoOrange
import com.temporun.run.wear.util.formattedDistance
import com.temporun.run.wear.util.formattedDuration
import com.temporun.run.wear.util.formattedPace
import com.temporun.run.wear.util.formattedRaceTime
import com.temporun.run.wear.workout.LiveMetrics
import com.temporun.run.wear.workout.RacePredictions
import com.temporun.run.wear.workout.WorkoutState
import com.temporun.run.wear.workout.WorkoutViewModel

/**
 * Tela ao vivo (estados running/paused). Equivalente ao LiveMetricsView.swift do Apple Watch
 * (TabView paginado). 7 páginas: Primárias, Energia+Zonas, Cardio, Altitude, Splits,
 * Predições e Controles. A página de Biomecânica do Apple não existe aqui — o Health
 * Services 1.0.0 não expõe Running Dynamics (ver CONTRACT_AUDIT.md).
 */
@Composable
fun LiveMetricsPager(vm: WorkoutViewModel) {
    val metrics by vm.metrics.collectAsStateWithLifecycle()
    val elapsed by vm.elapsedSeconds.collectAsStateWithLifecycle()
    val state by vm.state.collectAsStateWithLifecycle()

    val pagerState = rememberPagerState { 7 }
    val indicatorState = remember(pagerState) {
        object : PageIndicatorState {
            override val pageOffset: Float get() = pagerState.currentPageOffsetFraction
            override val selectedPage: Int get() = pagerState.currentPage
            override val pageCount: Int get() = pagerState.pageCount
        }
    }

    Box(Modifier.fillMaxSize()) {
        HorizontalPager(state = pagerState) { page ->
            when (page) {
                0 -> PrimaryPage(metrics, elapsed)
                1 -> EnergyZonesPage(metrics)
                2 -> CardioPage(metrics)
                3 -> AltitudePage(metrics)
                4 -> SplitsPage(metrics)
                5 -> PredictionsPage(metrics)
                else -> ControlsPage(
                    paused = state == WorkoutState.PAUSED,
                    onTogglePause = { vm.togglePause() },
                    onEnd = { vm.end() },
                )
            }
        }
        HorizontalPageIndicator(
            pageIndicatorState = indicatorState,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 1.dp),
        )
    }
}

// ── Página 1: Primárias ──────────────────────────────────────────────────────

@Composable
private fun PrimaryPage(m: LiveMetrics, elapsed: Long) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 10.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = elapsed.formattedDuration(),
            style = MaterialTheme.typography.display3,
            color = Color.White,
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            MetricCell(m.distanceKm.formattedDistance(), "km", TempoOrange)
            MetricCell(m.currentPace.formattedPace(), "/km")
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            ZoneDot(m.currentZone)
            Spacer(Modifier.width(4.dp))
            Text(
                "${m.heartRate.toInt()}",
                style = MaterialTheme.typography.title2,
                color = Color.White,
            )
            Text(" bpm", fontSize = 10.sp, color = Color.Gray)
            Spacer(Modifier.width(6.dp))
            ZoneBadge(m.currentZone)
        }
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 3.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            MetricCell(m.averagePace.formattedPace(), "médio")
            MetricCell("${m.cadence.toInt()}", "spm")
        }
    }
}

// ── Página 2: Energia + Zonas ────────────────────────────────────────────────

@Composable
private fun EnergyZonesPage(m: LiveMetrics) {
    ScrollPage("Energia & Zonas") {
        MetricRow("Calorias", "${m.activeEnergyBurned.toInt()} kcal", TempoOrange)
        Spacer(Modifier.height(4.dp))
        for (z in 1..5) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 1.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ZoneDot(z)
                Spacer(Modifier.width(5.dp))
                Text("Z$z · ${zoneName(z)}", fontSize = 11.sp, color = Color.Gray)
                Spacer(Modifier.weight(1f))
                Text(
                    m.timeInZone.getOrElse(z) { 0.0 }.formattedDuration(),
                    fontSize = 12.sp, color = Color.White,
                )
            }
        }
    }
}

// ── Página 3: Cardio ─────────────────────────────────────────────────────────

@Composable
private fun CardioPage(m: LiveMetrics) {
    ScrollPage("Cardio") {
        MetricRow("FC atual", "${m.heartRate.toInt()} bpm", zoneColor(m.currentZone))
        MetricRow("FC média", "${m.averageHeartRate.toInt()} bpm")
        MetricRow("FC mín", "${m.minHeartRate.toInt()} bpm", SystemBlue)
        MetricRow("FC máx", "${m.maxHeartRate.toInt()} bpm", SystemRed)
        if (m.vo2Max > 0) MetricRow("VO₂ máx", "%.1f ml/kg".format(m.vo2Max), SystemGreen)
    }
}

// ── Página 4: Altitude ───────────────────────────────────────────────────────

@Composable
private fun AltitudePage(m: LiveMetrics) {
    ScrollPage("Altitude") {
        MetricRow("Atual", "${m.currentAltitude.toInt()} m", TempoOrange)
        MetricRow("Ganho", "+ ${m.elevationGain.toInt()} m", SystemGreen)
        MetricRow("Perda", "- ${m.elevationLoss.toInt()} m", SystemRed)
        MetricRow("Máxima", "${m.maxAltitude.toInt()} m")
        MetricRow("Mínima", "${m.minAltitude.toInt()} m")
    }
}

// ── Página 5: Splits ─────────────────────────────────────────────────────────

@Composable
private fun SplitsPage(m: LiveMetrics) {
    ScrollPage("Splits") {
        if (m.splits.isEmpty()) {
            Text(
                "Primeiro split aos 1 km",
                fontSize = 11.sp, color = Color.Gray,
                modifier = Modifier.padding(top = 14.dp),
            )
        } else {
            val best = m.splits.minOfOrNull { it.paceSec } ?: 0.0
            for (s in m.splits) {
                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 1.dp)) {
                    Text("${s.km}", fontSize = 12.sp, color = Color.Gray, modifier = Modifier.width(22.dp))
                    Text(
                        s.paceSec.formattedPace(),
                        fontSize = 13.sp,
                        color = if (s.paceSec == best) TempoOrange else Color.White,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        if (s.avgHeartRate > 0) "${s.avgHeartRate.toInt()}" else "--",
                        fontSize = 12.sp, color = SystemRed,
                    )
                }
            }
        }
    }
}

// ── Página 6: Predições (Daniels) ────────────────────────────────────────────

@Composable
private fun PredictionsPage(m: LiveMetrics) {
    val p = RacePredictions.fromVo2Max(m.vo2Max)
    ScrollPage("Predição de prova") {
        if (m.vo2Max == 0.0) {
            Text(
                "Disponível após leitura\ndo VO₂ máx",
                fontSize = 11.sp, color = Color.Gray,
                modifier = Modifier.padding(top = 14.dp),
            )
        } else {
            MetricRow("5 km", p.km5.formattedRaceTime(), TempoOrange)
            MetricRow("10 km", p.km10.formattedRaceTime())
            MetricRow("Meia", p.halfMarathon.formattedRaceTime())
            MetricRow("Maratona", p.marathon.formattedRaceTime())
            Text(
                "Baseado no VO₂ máx · Daniels",
                fontSize = 9.sp, color = Color.Gray,
                modifier = Modifier.padding(top = 5.dp),
            )
        }
    }
}

// ── Página 7: Controles ──────────────────────────────────────────────────────

@Composable
private fun ControlsPage(paused: Boolean, onTogglePause: () -> Unit, onEnd: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(12.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Button(
            onClick = onTogglePause,
            colors = ButtonDefaults.buttonColors(backgroundColor = SystemGray.copy(alpha = 0.35f)),
        ) {
            Text(if (paused) "Continuar" else "Pausar", fontSize = 12.sp, color = Color.White)
        }
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = onEnd,
            colors = ButtonDefaults.buttonColors(backgroundColor = SystemRed.copy(alpha = 0.75f)),
        ) {
            Text("Encerrar", fontSize = 12.sp, color = Color.White)
        }
    }
}

// ── Subviews reutilizáveis ───────────────────────────────────────────────────

@Composable
private fun ScrollPage(title: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 14.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, fontSize = 13.sp, color = TempoOrange)
        Spacer(Modifier.height(4.dp))
        content()
    }
}

@Composable
private fun MetricCell(value: String, unit: String, color: Color = Color.White) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.title3, color = color)
        Text(unit, fontSize = 10.sp, color = Color.Gray)
    }
}

@Composable
private fun MetricRow(label: String, value: String, color: Color = Color.White) {
    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
        Text(label, fontSize = 11.sp, color = Color.Gray)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 12.sp, color = color)
    }
}

@Composable
private fun ZoneDot(zone: Int) {
    Box(Modifier.size(8.dp).background(zoneColor(zone), CircleShape))
}

@Composable
private fun ZoneBadge(zone: Int) {
    Box(
        Modifier.background(zoneColor(zone), CircleShape).padding(horizontal = 6.dp, vertical = 1.dp),
    ) {
        Text("Z$zone", fontSize = 10.sp, color = Color.Black)
    }
}

fun zoneColor(zone: Int): Color = when (zone) {
    1 -> SystemBlue   // azul — recuperação
    2 -> SystemGreen   // verde — base aeróbica
    3 -> SystemYellow   // amarelo — tempo
    4 -> TempoOrange         // laranja — limiar
    5 -> SystemRed   // vermelho — VO₂ máx
    else -> SystemGray
}

private fun zoneName(zone: Int): String =
    listOf("—", "Recuperação", "Base aeróbica", "Tempo", "Limiar", "VO₂ máx")[zone]
