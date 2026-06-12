package com.temporun.run.wear.presentation.start

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
 * Pede as permissões de sensores/GPS/notificação em runtime antes de iniciar —
 * o Health Services degrada graciosamente para o que for concedido.
 * TODO(Fase 3): abas Hoje / Semana / Status.
 */
@Composable
fun StartScreen(vm: WorkoutViewModel) {
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        // Inicia mesmo com concessão parcial: sem GPS ainda há FC/passos (corrida indoor)
        vm.start()
    }

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
        Button(onClick = {
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.BODY_SENSORS,
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACTIVITY_RECOGNITION,
                    Manifest.permission.POST_NOTIFICATIONS,
                )
            )
        }) {
            Text("Iniciar")
        }
    }
}
