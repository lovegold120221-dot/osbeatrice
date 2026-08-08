package ai.eburon.beatrice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Starts the Beatrice foreground service automatically after device boot so
 * the agent can accept voice/device tasks without the user reopening the app.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BeatriceOS", "Boot completed — starting Beatrice foreground service")
            BeatriceForegroundService.start(context)
        }
    }
}
