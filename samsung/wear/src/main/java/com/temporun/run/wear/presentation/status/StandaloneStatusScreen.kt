package com.temporun.run.wear.presentation.status

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
 * Status do modo standalone (aba "Status"). Equivalente ao StandaloneStatusView.swift.
 * TODO(Fase 5): rede, credenciais Supabase, fila pendente, botão sincronizar.
 */
@Composable
fun StandaloneStatusScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(8.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Status", color = MaterialTheme.colors.primary, style = MaterialTheme.typography.title3)
        Text(
            "Modo standalone\nFase 5",
            style = MaterialTheme.typography.caption2,
            textAlign = TextAlign.Center,
        )
    }
}
