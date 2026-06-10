package com.temporun.run.wear.workout

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RacePredictionsTest {

    @Test
    fun `vo2 zero produz predicoes zeradas`() {
        val p = RacePredictions.fromVo2Max(0.0)
        assertEquals(0.0, p.km5, 0.001)
        assertEquals(0.0, p.marathon, 0.001)
    }

    @Test
    fun `vo2 50 preve 5k em torno de 19 minutos (Daniels)`() {
        val p = RacePredictions.fromVo2Max(50.0)
        // (50*0.9757 + 3.5)/0.2 = 261.4 m/min → 5000/261.4*60 ≈ 1147 s
        assertTrue("5k=${p.km5}", p.km5 in 1100.0..1200.0)
    }

    @Test
    fun `tempos crescem com a distancia e vo2 maior melhora os tempos`() {
        val p = RacePredictions.fromVo2Max(50.0)
        assertTrue(p.km5 < p.km10)
        assertTrue(p.km10 < p.halfMarathon)
        assertTrue(p.halfMarathon < p.marathon)

        val better = RacePredictions.fromVo2Max(60.0)
        assertTrue(better.marathon < p.marathon)
    }
}
