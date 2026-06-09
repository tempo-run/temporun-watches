package com.temporun.run.wear.presentation.plan

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text

/**
 * Semana de treino (aba "Semana"). Equivalente ao WeekPlanView.swift.
 * TODO(Fase 3): 7 dias com destaque no dia atual.
 */
@Composable
fun WeekPlanScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(8.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Semana", color = MaterialTheme.colors.primary, style = MaterialTheme.typography.title3)
        Text("Fase 3", style = MaterialTheme.typography.caption2)
    }
}
