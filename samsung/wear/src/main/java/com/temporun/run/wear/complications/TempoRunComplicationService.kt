package com.temporun.run.wear.complications

import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService

/**
 * Fornece dados para complications da watch face. Equivalente ao ComplicationProvider.swift
 * (ClockKit). Tipos suportados (declarados no manifest):
 * - SHORT_TEXT  → "Nkm" (km da semana)
 * - RANGED_VALUE → progresso semanal (km / meta) com texto "Nkm"
 * - LONG_TEXT   → próximo treino ("Qua: Tempo Run · 8km")
 *
 * Os dados vêm de [ComplicationStore] (sincronizados do celular via Data Layer).
 */
class TempoRunComplicationService : SuspendingComplicationDataSourceService() {

    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        complicationFor(type, ComplicationState(weeklyKm = 24.0, weeklyGoalKm = 40.0, streakDays = 5,
            nextWorkoutType = "Tempo Run", nextWorkoutKm = 8.0, nextWorkoutDay = "Qua"))

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? =
        complicationFor(request.complicationType, ComplicationStore.load(this))

    private fun complicationFor(type: ComplicationType, s: ComplicationState): ComplicationData? {
        val kmText = "${s.weeklyKmInt()}km"
        return when (type) {
            ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(
                text = plain(kmText),
                contentDescription = plain("${s.weeklyKmInt()} km na semana"),
            ).build()

            ComplicationType.RANGED_VALUE -> RangedValueComplicationData.Builder(
                value = s.weeklyKm.toFloat(),
                min = 0f,
                max = if (s.weeklyGoalKm > 0) s.weeklyGoalKm.toFloat() else 1f,
                contentDescription = plain("Progresso semanal"),
            ).setText(plain(kmText)).build()

            ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(
                text = plain(s.nextWorkoutLabel()),
                contentDescription = plain("Próximo treino"),
            ).build()

            else -> null
        }
    }

    private fun plain(text: String) = PlainComplicationText.Builder(text).build()
}
