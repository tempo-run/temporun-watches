package com.temporun.run.wear.workout

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.wear.ongoing.OngoingActivity
import com.temporun.run.wear.R
import com.temporun.run.wear.presentation.MainActivity

/**
 * Foreground service que mantém a corrida gravando com a tela apagada / no pulso — exigência
 * do Android sem equivalente no watchOS (lá o HKWorkoutSession já cuida disso).
 *
 * Usa a Ongoing Activity API: a corrida aparece como atividade em andamento na watch face
 * e no app launcher, com toque levando de volta ao app.
 *
 * TODO(Fase 2): atualizar o texto da notificação com pace/FC/tempo ao vivo.
 */
class WorkoutService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Restart pelo sistema (intent nulo): não há estado de sessão a recompor aqui
        // (a captura vive no Health Services). Não re-publica a notificação zumbi.
        if (intent == null) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        ensureChannel()

        val touchIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(getString(R.string.app_name))
            .setContentText("Corrida em andamento")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setContentIntent(touchIntent)

        // Ongoing Activity: indicador de atividade em andamento na watch face
        val ongoingActivity = OngoingActivity.Builder(applicationContext, NOTIF_ID, builder)
            .setStaticIcon(R.drawable.ic_launcher)
            .setTouchIntent(touchIntent)
            .build()
        ongoingActivity.apply(applicationContext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, builder.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(NOTIF_ID, builder.build())
        }
        // Sem START_STICKY: nada a restaurar a partir de um restart com intent nulo.
        return START_NOT_STICKY
    }

    private fun ensureChannel() {
        val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Corrida", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    companion object {
        private const val CHANNEL_ID = "workout"
        private const val NOTIF_ID = 1
    }
}
