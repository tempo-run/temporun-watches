package com.temporun.run.wear.workout

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SplitTrackerTest {

    @Test
    fun `nao fecha split antes de 1 km`() {
        val t = SplitTracker()
        assertFalse(t.checkSplit(0.99, 320.0, 5.0))
        assertTrue(t.splits.isEmpty())
    }

    @Test
    fun `fecha o primeiro split ao cruzar 1 km com pace igual a duracao`() {
        val t = SplitTracker()
        t.registerHeartRate(140.0)
        t.registerHeartRate(150.0)
        assertTrue(t.checkSplit(1.01, 330.0, 12.0))
        val s = t.splits.single()
        assertEquals(1, s.km)
        assertEquals(330.0, s.durationSec, 0.001)
        assertEquals(330.0, s.paceSec, 0.001)
        assertEquals(145.0, s.avgHeartRate, 0.001)
        assertEquals(12.0, s.elevationGain, 0.001)
    }

    @Test
    fun `segundo split usa duracao e elevacao relativas ao primeiro`() {
        val t = SplitTracker()
        assertTrue(t.checkSplit(1.0, 300.0, 10.0))
        t.registerHeartRate(160.0)
        assertTrue(t.checkSplit(2.0, 640.0, 25.0))
        val s = t.splits[1]
        assertEquals(2, s.km)
        assertEquals(340.0, s.durationSec, 0.001)   // 640 - 300
        assertEquals(15.0, s.elevationGain, 0.001)  // 25 - 10
        assertEquals(160.0, s.avgHeartRate, 0.001)  // FC só do 2º split (reset no fechamento)
    }

    @Test
    fun `nao fecha o mesmo km duas vezes`() {
        val t = SplitTracker()
        assertTrue(t.checkSplit(1.2, 350.0, 0.0))
        assertFalse(t.checkSplit(1.8, 500.0, 0.0))
        assertEquals(1, t.splits.size)
    }

    @Test
    fun `reset limpa estado`() {
        val t = SplitTracker()
        t.checkSplit(1.0, 300.0, 5.0)
        t.reset()
        assertTrue(t.splits.isEmpty())
        // depois do reset, o km 1 pode ser fechado de novo
        assertTrue(t.checkSplit(1.0, 290.0, 0.0))
    }
}
