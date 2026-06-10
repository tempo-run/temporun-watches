package com.temporun.run.wear.util

import org.junit.Assert.assertEquals
import org.junit.Test

class FormattersTest {

    @Test
    fun `pace formatado como m ss`() {
        assertEquals("5:30", 330.0.formattedPace())
        assertEquals("10:05", 605.0.formattedPace())
    }

    @Test
    fun `pace invalido vira placeholder`() {
        assertEquals("--:--", 0.0.formattedPace())
        assertEquals("--:--", (-10.0).formattedPace())
        assertEquals("--:--", Double.NaN.formattedPace())
        assertEquals("--:--", Double.POSITIVE_INFINITY.formattedPace())
    }

    @Test
    fun `duracao curta e longa`() {
        assertEquals("0:45", 45.0.formattedDuration())
        assertEquals("28:20", 1700.0.formattedDuration())
        assertEquals("1:01:05", 3665.0.formattedDuration())
        assertEquals("28:20", 1700L.formattedDuration())
    }

    @Test
    fun `distancia com duas casas e ponto decimal`() {
        assertEquals("5.04", 5.039.formattedDistance())
        assertEquals("0.00", 0.0.formattedDistance())
    }

    @Test
    fun `tempo de prova sempre com horas`() {
        assertEquals("0:19:07", 1147.0.formattedRaceTime())
        assertEquals("3:05:00", 11100.0.formattedRaceTime())
    }
}
