package com.temporun.run.wear.complications

import android.content.ComponentName
import android.content.Context
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester

/**
 * Persiste o [ComplicationState] (SharedPreferences) e, ao receber novos dados do celular,
 * pede atualização das complications e do tile. Equivalente ao cache + push do Apple.
 */
object ComplicationStore {
    private const val PREFS = "temporun_wear"
    private const val KEY = "complicationData"

    fun load(context: Context): ComplicationState {
        val s = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
        return ComplicationState.fromJson(s)
    }

    /** Recebe o JSON do celular, persiste e dispara o refresh de complications + tile. */
    fun apply(context: Context, json: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
        requestRefresh(context.applicationContext)
    }

    private fun requestRefresh(context: Context) {
        runCatching {
            ComplicationDataSourceUpdateRequester
                .create(context, ComponentName(context, TempoRunComplicationService::class.java))
                .requestUpdateAll()
        }
        runCatching {
            TileService.getUpdater(context)
                .requestUpdate(com.temporun.run.wear.tiles.TempoRunTileService::class.java)
        }
    }
}
