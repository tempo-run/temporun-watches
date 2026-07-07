package com.temporun.run.wear.presentation.status

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.temporun.run.wear.network.NetworkMonitor
import com.temporun.run.wear.network.OfflineQueue
import com.temporun.run.wear.network.SupabaseConfig
import com.temporun.run.wear.presentation.theme.SystemGreen
import com.temporun.run.wear.presentation.theme.SystemRed
import com.temporun.run.wear.presentation.theme.TempoOrange
import kotlinx.coroutines.launch

/**
 * Status do modo standalone (aba "Status"). Equivalente ao StandaloneStatusView.swift:
 * rede, credenciais Supabase, fila pendente e botão de sincronizar.
 */
@Composable
fun StandaloneStatusScreen() {
    val context = LocalContext.current
    val connected by NetworkMonitor.isConnected.collectAsStateWithLifecycle()
    val pending by OfflineQueue.pending.collectAsStateWithLifecycle()
    val configured = SupabaseConfig.isConfigured(context)
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 14.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Standalone", style = MaterialTheme.typography.title3, color = TempoOrange)
        Spacer(Modifier.height(6.dp))

        StatusRow("Rede", if (connected) "conectado" else "offline", if (connected) Green else Color.Gray)
        StatusRow("Credenciais", if (configured) "ok" else "faltando", if (configured) Green else SystemRed)
        StatusRow("Fila pendente", "$pending", if (pending > 0) TempoOrange else Color.White)

        Spacer(Modifier.height(10.dp))
        if (pending > 0 && connected) {
            Button(onClick = { scope.launch { OfflineQueue.syncAll() } }) {
                Text("Sincronizar ($pending)", fontSize = 12.sp)
            }
        } else if (!configured) {
            Text(
                "Faça login no app do celular\npara habilitar o standalone.",
                fontSize = 10.sp, color = Color.Gray,
            )
        }
    }
}

private val Green = SystemGreen

@Composable
private fun StatusRow(label: String, value: String, color: Color) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, fontSize = 11.sp, color = Color.Gray)
        Text(value, fontSize = 11.sp, color = color)
    }
}
