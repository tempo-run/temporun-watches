package com.temporun.run.wear.tiles

import androidx.wear.protolayout.ColorBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.PrimaryLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.temporun.run.wear.complications.ComplicationStore

/**
 * Tile do TempoRun (Smart Stack). Equivalente ao WidgetBundle.swift (RectangularView): progresso
 * semanal (km / meta), streak e próximo treino. Dados de [ComplicationStore] (vindos do celular).
 */
class TempoRunTileService : TileService() {

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest,
    ): ListenableFuture<TileBuilders.Tile> {
        val s = ComplicationStore.load(this)
        val device = requestParams.deviceConfiguration

        val goal = if (s.weeklyGoalKm > 0) s.weeklyGoalKm.toInt().toString() else "—"
        val layout = PrimaryLayout.Builder(device)
            .setResponsiveContentInsetEnabled(true)
            .setPrimaryLabelTextContent(
                Text.Builder(this, "Semana · 🔥${s.streakDays}")
                    .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                    .setColor(ColorBuilders.argb(GRAY))
                    .build()
            )
            .setContent(
                Text.Builder(this, "${s.weeklyKmInt()} / $goal km")
                    .setTypography(Typography.TYPOGRAPHY_DISPLAY2)
                    .setColor(ColorBuilders.argb(ORANGE))
                    .build()
            )
            .setSecondaryLabelTextContent(
                Text.Builder(this, s.nextWorkoutLabel())
                    .setTypography(Typography.TYPOGRAPHY_CAPTION2)
                    .setColor(ColorBuilders.argb(WHITE))
                    .build()
            )
            .build()

        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(layout))
            .setFreshnessIntervalMillis(30 * 60 * 1000L) // 30 min
            .build()
        return Futures.immediateFuture(tile)
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<ResourceBuilders.Resources> =
        Futures.immediateFuture(
            ResourceBuilders.Resources.Builder().setVersion(RESOURCES_VERSION).build()
        )

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val ORANGE = 0xFFFF6B35.toInt()
        private const val WHITE = 0xFFFFFFFF.toInt()
        private const val GRAY = 0xFF8E8E93.toInt()   // systemGray (Apple Watch)
    }
}
