package com.temporun.run.wear.network

/**
 * Monitor de conectividade do relógio (WiFi/celular). Equivalente ao NetworkMonitor.swift
 * (NWPathMonitor).
 *
 * TODO(Fase 5): implementar com ConnectivityManager.NetworkCallback e disparar
 *               OfflineQueue.syncAll() quando a rede voltar.
 */
object NetworkMonitor {
    val isConnected: Boolean get() = false // TODO(Fase 5)
}
