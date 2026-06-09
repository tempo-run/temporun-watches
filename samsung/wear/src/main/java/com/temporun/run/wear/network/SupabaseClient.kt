package com.temporun.run.wear.network

import com.temporun.run.wear.connectivity.WorkoutPayload

/**
 * Cliente do modo standalone (relógio com rede própria → Supabase direto). Equivalente ao
 * SupabaseClient.swift. Bate na MESMA edge function watch-workout-save (DECISIONS.md D1).
 *
 * TODO(Fase 5): implementar com Ktor — POST {url}/functions/v1/watch-workout-save com
 *               headers apikey + Authorization Bearer; refresh de token no 401; resultado
 *               { corrida_id, xp_ganho, streak_atual, novos_recordes, is_duplicate }.
 *               source = "wear_os_standalone".
 */
object SupabaseClient {
    fun isConfigured(): Boolean = false // TODO(Fase 5): checar credenciais recebidas do celular

    suspend fun insertCorrida(payload: WorkoutPayload): Result<Unit> {
        // TODO(Fase 5)
        return Result.failure(NotImplementedError("Standalone save — Fase 5"))
    }
}
