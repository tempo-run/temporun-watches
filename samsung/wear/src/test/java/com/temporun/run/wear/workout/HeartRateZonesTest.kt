package com.temporun.run.wear.workout

import org.junit.Assert.assertEquals
import org.junit.Test

class HeartRateZonesTest {

    private val zones = HeartRateZones(maxHR = 200.0)

    @Test
    fun `abaixo de 50 por cento e zona 0`() = assertEquals(0, zones.zone(95.0))

    @Test
    fun `limites das cinco zonas`() {
        assertEquals(1, zones.zone(100.0))  // 50%
        assertEquals(1, zones.zone(115.0))
        assertEquals(2, zones.zone(125.0))  // 60-70%
        assertEquals(3, zones.zone(150.0))  // 70-80%
        assertEquals(4, zones.zone(170.0))  // 80-90%
        assertEquals(5, zones.zone(190.0))  // 90-100%
    }

    @Test
    fun `acima do maximo satura em zona 5`() = assertEquals(5, zones.zone(210.0))
}
