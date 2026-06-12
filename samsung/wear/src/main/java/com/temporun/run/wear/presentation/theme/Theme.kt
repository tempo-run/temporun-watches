package com.temporun.run.wear.presentation.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.MaterialTheme

/** Cor de acento do TempoRun (mesma do app iOS/Android). */
val TempoOrange = Color(0xFFFF6B35)

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
