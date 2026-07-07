package com.temporun.run.wear.presentation.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme

/** Cor de acento do TempoRun (mesma do app iOS/Android). */
val TempoOrange = Color(0xFFFF6B35)

// Cores de sistema do SwiftUI (valores dark do watchOS), espelhando o app Apple Watch
// (Extensions.swift + zoneColor()/SummaryView/TodayWorkoutView). Substituem os tons Material.
val SystemRed = Color(0xFFFF453A)
val SystemBlue = Color(0xFF0A84FF)
val SystemGreen = Color(0xFF30D158)
val SystemYellow = Color(0xFFFFD60A)
val SystemGray = Color(0xFF8E8E93)

private val WearColors = Colors(
    primary = TempoOrange,
    primaryVariant = Color(0xFFCC471F),
    secondary = TempoOrange,
    secondaryVariant = Color(0xFFCC471F),
    background = Color.Black,
    surface = Color(0xFF1A1A1A),
    onPrimary = Color.Black,
    onSecondary = Color.Black,
    onBackground = Color.White,
    onSurface = Color.White,
)

@Composable
fun TempoRunWearTheme(content: @Composable () -> Unit) {
    MaterialTheme(colors = WearColors, content = content)
}
