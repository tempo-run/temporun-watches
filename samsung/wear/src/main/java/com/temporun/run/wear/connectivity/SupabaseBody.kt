package com.temporun.run.wear.connectivity

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject

/**
 * Serializa o mapa do contrato (`WorkoutPayload.toSupabaseMap()`) para uma string JSON pronta
 * para ser o corpo do POST à edge function watch-workout-save.
 *
 * Mantém o contrato com FONTE ÚNICA no relógio: o celular (plugin Capacitor) só repassa esta
 * string verbatim para a edge function, sem precisar conhecer o schema. Ver DECISIONS.md (D1).
 */
fun Map<String, Any?>.toJsonString(): String =
    buildJsonObject { this@toJsonString.forEach { (k, v) -> put(k, v.toJsonElement()) } }.toString()

private fun Any?.toJsonElement(): JsonElement = when (this) {
    null -> JsonNull
    is JsonElement -> this
    is Boolean -> JsonPrimitive(this)
    is Number -> JsonPrimitive(this)
    is String -> JsonPrimitive(this)
    is Map<*, *> -> buildJsonObject {
        this@toJsonElement.forEach { (k, v) -> put(k.toString(), v.toJsonElement()) }
    }
    is List<*> -> buildJsonArray { this@toJsonElement.forEach { add(it.toJsonElement()) } }
    else -> JsonPrimitive(toString())
}
