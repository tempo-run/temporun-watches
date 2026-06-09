package com.temporun.run.wear.presentation.plan

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text

/**
 * Treino do dia (aba "Hoje"). Equivalente ao TodayWorkoutView.swift.
 * TODO(Fase 3): tipo, distância-alvo, pace-alvo, breakdown da sessão, alerta de lesão,
 *               botão "Iniciar treino". Dados vêm do plano recebido via Data Layer.
 */
@Composable
fun TodayWorkoutScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(8.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Treino de hoje", color = MaterialTheme.colors.primary, style = MaterialTheme.typography.title3)
        Text(
            "Disponível na Fase 3\n(plano vindo do celular)",
            style = MaterialTheme.typography.caption2,
            textAlign = TextAlign.Center,
        )
    }
}
