package com.temporun.run.wear.connectivity

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Atualização ao vivo enviada ao celular durante a corrida (pace/FC/distância/tempo).
 * Trafega como bytes JSON via MessageClient. Espelha o liveUpdate do WatchSessionManager.swift.
 */
@Serializable
data class LiveUpdate(
    val distanceKm: Double,
    val paceSec: Double,
    val heartRate: Double,
    val elapsedSec: Long,
) {
    fun toBytes(): ByteArray = Json.encodeToString(serializer(), this).toByteArray()

    companion object {
        fun fromBytes(bytes: ByteArray): LiveUpdate =
            Json.decodeFromString(serializer(), bytes.decodeToString())
    }
}
