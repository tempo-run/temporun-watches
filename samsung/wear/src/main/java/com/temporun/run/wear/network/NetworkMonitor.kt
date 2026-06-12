package com.temporun.run.wear.network

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Monitor de conectividade do relógio (WiFi/celular). Equivalente ao NetworkMonitor.swift.
 * Quando a rede volta, dispara o flush da [OfflineQueue].
 */
object NetworkMonitor {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    @Volatile private var initialized = false

    fun ensureInit(context: Context) {
        if (initialized) return
        initialized = true
        val cm = context.applicationContext
            .getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        _isConnected.value = cm.activeNetwork
            ?.let { cm.getNetworkCapabilities(it) }
            ?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true

        cm.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                val was = _isConnected.value
                _isConnected.value = true
                if (!was) scope.launch { OfflineQueue.syncAll() } // rede voltou → sincroniza
            }
            override fun onLost(network: Network) {
                _isConnected.value = false
            }
        })
    }
}
