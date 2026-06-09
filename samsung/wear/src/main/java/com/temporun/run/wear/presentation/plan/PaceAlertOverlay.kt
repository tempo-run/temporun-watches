package com.temporun.run.wear.presentation.plan

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.training.PaceStatus

/**
 * Overlay de alerta de pace fora da zona-alvo. Equivalente ao PaceAlertOverlay.swift.
 * TODO(Fase 3): animação + auto-dismiss (4s) + haptic, exibido sobre a tela ao vivo.
 */
@Composable
fun PaceAlertOverlay(status: PaceStatus, paceAlvo: String) {
    if (status == PaceStatus.OK) return
    Box(
        modifier = Modifier.fillMaxWidth().padding(8.dp),
        contentAlignment = Alignment.Center,
    ) {
        val msg = when (status) {
            PaceStatus.TOO_FAST -> "Muito rápido · alvo $paceAlvo"
            PaceStatus.TOO_SLOW -> "Muito lento · alvo $paceAlvo"
            PaceStatus.OK -> ""
        }
        Text(msg, color = MaterialTheme.colors.primary, style = MaterialTheme.typography.caption1)
    }
}
