package com.example.adhan_and_prayer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Lightweight BroadcastReceiver for AlarmManager exact prayer triggers.
 *
 * Delegates all long-running audio playback, WakeLock management, and foreground
 * notification lifecycle to [AdhanPlaybackService] so playback survives when the
 * application is removed from Android Recent Apps.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanAlarmReceiver"
        const val ACTION_ALARM_TRIGGER = "com.example.adhan_and_prayer.ALARM_TRIGGER"
        const val ACTION_STOP_ADHAN = "com.example.adhan_and_prayer.ACTION_STOP_ADHAN"
        const val NOTIFICATION_ID_ADHAN = AdhanPlaybackService.NOTIFICATION_ID_ADHAN

        /**
         * Authoritative static stop method accessible by both BroadcastReceiver
         * and MainActivity (Flutter MethodChannel).
         * Idempotent and delegates to [AdhanPlaybackService.stopPlayback].
         */
        @Synchronized
        fun stopAdhan(context: Context) {
            Log.i(TAG, "AdhanAlarmReceiver.stopAdhan() delegating to AdhanPlaybackService")
            AdhanPlaybackService.stopPlayback(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "onReceive triggered with action: $action")

        if (action == ACTION_STOP_ADHAN) {
            Log.i(TAG, "Received ACTION_STOP_ADHAN — stopping playback service")
            stopAdhan(context)
            return
        }

        val alarmId = intent.getIntExtra(AdhanPlaybackService.EXTRA_ALARM_ID, -1)
        val prayerName = intent.getStringExtra(AdhanPlaybackService.EXTRA_PRAYER_NAME)
            ?.takeIf { it.isNotBlank() } ?: "Prayer"
        val reciterAsset = intent.getStringExtra(AdhanPlaybackService.EXTRA_RECITER_ASSET)
            ?: "assets/audio/adhan_abdulbasit.mp3"
        val isAdhanEnabled = intent.getBooleanExtra(AdhanPlaybackService.EXTRA_IS_ADHAN_ENABLED, true)

        if (isAdhanEnabled && !AdhanPlaybackService.isValidAudioAssetPath(reciterAsset)) {
            Log.e(TAG, "Rejected invalid audio asset path in alarm intent: '$reciterAsset'")
            return
        }

        Log.i(TAG, "Dispatching alarm to AdhanPlaybackService: id=$alarmId, prayer=$prayerName, enabled=$isAdhanEnabled")

        val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
            this.action = AdhanPlaybackService.ACTION_START_ADHAN
            putExtra(AdhanPlaybackService.EXTRA_ALARM_ID, alarmId)
            putExtra(AdhanPlaybackService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanPlaybackService.EXTRA_RECITER_ASSET, reciterAsset)
            putExtra(AdhanPlaybackService.EXTRA_IS_ADHAN_ENABLED, isAdhanEnabled)
        }

        try {
            ContextCompat.startForegroundService(context, serviceIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start AdhanPlaybackService for $prayerName", e)
        }
    }
}
