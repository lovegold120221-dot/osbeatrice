package ai.eburon.beatrice

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps Beatrice alive in the background.
 * Runs while the user is in an active voice session so the WebView-hosted
 * Gemini Live session is not killed by Android.
 */
class BeatriceForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "beatrice_voice_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "ai.eburon.beatrice.START_FOREGROUND"
        private const val ACTION_STOP = "ai.eburon.beatrice.STOP_FOREGROUND"

        fun start(context: Context) {
            val intent = Intent(context, BeatriceForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, BeatriceForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                Log.d("BeatriceOS", "Stopping foreground service")
                stopForeground(true)
                stopSelf(startId)
            }
            else -> {
                Log.d("BeatriceOS", "Starting foreground service")
                startForeground(NOTIFICATION_ID, buildNotification())
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Beatrice Voice")
            .setContentText("Voice session is active in the background")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Beatrice Voice",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps Beatrice voice session running in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
