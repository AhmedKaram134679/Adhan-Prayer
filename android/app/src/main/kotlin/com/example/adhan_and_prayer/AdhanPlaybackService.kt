package com.example.adhan_and_prayer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import io.flutter.FlutterInjector

/**
 * Dedicated Android Foreground Service that owns the MediaPlayer and WakeLock
 * lifecycle for scheduled Adhan playback.
 *
 * By running as a mediaPlayback foreground service, scheduled Adhan audio
 * survives when the Flutter Activity is closed or removed from Recent Apps.
 */
class AdhanPlaybackService : Service() {
    companion object {
        private const val TAG = "AdhanPlaybackService"
        const val CHANNEL_ID = "adhan_prayer_channel_v2"
        const val LEGACY_CHANNEL_ID = "adhan_prayer_channel"
        const val NOTIFICATION_ID_ADHAN = 1001

        const val ACTION_START_ADHAN = "com.example.adhan_and_prayer.ACTION_START_ADHAN"
        const val ACTION_STOP_ADHAN = "com.example.adhan_and_prayer.ACTION_STOP_ADHAN"

        const val EXTRA_ALARM_ID = "id"
        const val EXTRA_PRAYER_NAME = "prayerName"
        const val EXTRA_RECITER_ASSET = "reciterAssetPath"
        const val EXTRA_IS_ADHAN_ENABLED = "isAdhanEnabled"

        private const val DUPLICATE_WINDOW_MS = 30_000L
        private const val WAKE_LOCK_TIMEOUT_MS = 240_000L // 4 minutes safety cap

        @Volatile
        var isRunning: Boolean = false
            private set

        /**
         * Validates that an audio asset path points to a bundled Adhan audio file.
         */
        fun isValidAudioAssetPath(assetPath: String?): Boolean {
            if (assetPath.isNullOrBlank()) return false
            val trimmed = assetPath.trim()
            if (trimmed.contains("..")) return false
            if (!trimmed.startsWith("assets/audio/")) return false
            val lower = trimmed.lowercase()
            return lower.endsWith(".mp3") || lower.endsWith(".wav") || lower.endsWith(".ogg")
        }

        /**
         * Stops any active Adhan playback service and cancels the Adhan notification.
         * Safe to call from BroadcastReceiver, MainActivity MethodChannel, or anywhere else.
         */
        fun stopPlayback(context: Context) {
            Log.i(TAG, "stopPlayback() requested")
            try {
                if (isRunning) {
                    val stopIntent = Intent(context, AdhanPlaybackService::class.java).apply {
                        action = ACTION_STOP_ADHAN
                    }
                    context.startService(stopIntent)
                } else {
                    context.stopService(Intent(context, AdhanPlaybackService::class.java))
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error delivering stop command to AdhanPlaybackService: ${e.message}")
            }

            // Ensure notification is removed even if service was not running
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIFICATION_ID_ADHAN)
            } catch (e: Exception) {
                Log.w(TAG, "Error canceling notification during stopPlayback: ${e.message}")
            }
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var activeAlarmId: Int = -1
    private var lastStartTimeMs: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        Log.i(TAG, "AdhanPlaybackService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.i(TAG, "onStartCommand: action=$action, startId=$startId")

        if (action == ACTION_STOP_ADHAN) {
            Log.i(TAG, "Received ACTION_STOP_ADHAN — stopping playback and service")
            stopAndCleanup(removeNotification = true)
            return START_NOT_STICKY
        }

        val alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, -1) ?: -1
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME)?.takeIf { it.isNotBlank() } ?: "Prayer"
        val reciterAsset = intent?.getStringExtra(EXTRA_RECITER_ASSET) ?: "assets/audio/adhan_abdulbasit.mp3"
        val isAdhanEnabled = intent?.getBooleanExtra(EXTRA_IS_ADHAN_ENABLED, true) ?: true

        // Build and promote to foreground IMMEDIATELY to satisfy Android foreground-service contract
        val notification = buildNotification(prayerName)
        try {
            promoteToForeground(notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to promote AdhanPlaybackService to foreground", e)
            stopAndCleanup(removeNotification = false)
            return START_NOT_STICKY
        }

        if (!isAdhanEnabled) {
            Log.i(TAG, "Adhan audio disabled for $prayerName; notification posted, stopping service")
            detachForegroundAndStop()
            return START_NOT_STICKY
        }

        // Deduplicate rapid repeated triggers for the same alarm while already playing
        val now = System.currentTimeMillis()
        if (alarmId != -1 &&
            alarmId == activeAlarmId &&
            (now - lastStartTimeMs) < DUPLICATE_WINDOW_MS &&
            isMediaPlayerPlaying()
        ) {
            Log.i(TAG, "Ignoring duplicate start request for alarmId=$alarmId ($prayerName)")
            return START_NOT_STICKY
        }

        if (!isValidAudioAssetPath(reciterAsset)) {
            Log.e(TAG, "Rejected invalid Adhan audio asset path: '$reciterAsset'")
            detachForegroundAndStop()
            return START_NOT_STICKY
        }

        activeAlarmId = alarmId
        lastStartTimeMs = now

        acquireWakeLock()
        startMediaPlayback(reciterAsset, prayerName)

        return START_NOT_STICKY
    }

    private fun promoteToForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID_ADHAN,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID_ADHAN, notification)
        }
    }

    private fun isMediaPlayerPlaying(): Boolean {
        return try {
            mediaPlayer?.isPlaying == true
        } catch (_: IllegalStateException) {
            false
        }
    }

    private fun acquireWakeLock() {
        try {
            releaseWakeLock()
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "AdhanAndPrayer:PlaybackServiceWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(WAKE_LOCK_TIMEOUT_MS)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to acquire WakeLock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let { wl ->
                if (wl.isHeld) {
                    wl.release()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing WakeLock: ${e.message}")
        } finally {
            wakeLock = null
        }
    }

    private fun releaseMediaPlayer() {
        try {
            mediaPlayer?.let { mp ->
                try {
                    if (mp.isPlaying) {
                        mp.stop()
                    }
                } catch (_: IllegalStateException) {
                }
                mp.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing MediaPlayer: ${e.message}")
        } finally {
            mediaPlayer = null
        }
    }

    private fun openAssetDescriptor(assetPath: String): AssetFileDescriptor {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            val assetKey = loader.getLookupKeyForAsset(assetPath)
            return assets.openFd(assetKey)
        } catch (primaryError: Exception) {
            Log.w(TAG, "Primary FlutterLoader lookup failed for $assetPath, trying direct flutter_assets path: ${primaryError.message}")
            return assets.openFd("flutter_assets/$assetPath")
        }
    }

    private fun readPersistedAdhanVolume(): Float {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!prefs.contains("flutter.adhan_volume")) {
                return 1.0f
            }
            val rawFloat = try {
                prefs.getFloat("flutter.adhan_volume", 1.0f)
            } catch (_: ClassCastException) {
                try {
                    val bits = prefs.getLong("flutter.adhan_volume", java.lang.Double.doubleToRawLongBits(1.0))
                    java.lang.Double.longBitsToDouble(bits).toFloat()
                } catch (_: ClassCastException) {
                    val strVal = prefs.getString("flutter.adhan_volume", "1.0") ?: "1.0"
                    strVal.toFloatOrNull() ?: 1.0f
                }
            }
            rawFloat.coerceIn(0.0f, 1.0f)
        } catch (e: Exception) {
            Log.w(TAG, "Error reading flutter.adhan_volume, falling back to 1.0", e)
            1.0f
        }
    }

    private fun startMediaPlayback(assetPath: String, prayerName: String) {
        releaseMediaPlayer()

        try {
            val afd = openAssetDescriptor(assetPath)
            val player = MediaPlayer()
            try {
                player.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )
                player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            } finally {
                afd.close()
            }

            val volume = readPersistedAdhanVolume()
            player.setVolume(volume, volume)
            Log.i(TAG, "Starting foreground Adhan playback for $prayerName | asset=$assetPath | volume=$volume")

            player.setOnCompletionListener {
                Log.i(TAG, "Adhan playback completed for $prayerName")
                detachForegroundAndStop()
            }

            player.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer error during Adhan playback: what=$what, extra=$extra")
                detachForegroundAndStop()
                true
            }

            player.prepare()
            player.start()
            mediaPlayer = player
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Adhan MediaPlayer for $assetPath", e)
            detachForegroundAndStop()
        }
    }

    private fun stopAndCleanup(removeNotification: Boolean) {
        releaseMediaPlayer()
        releaseWakeLock()
        activeAlarmId = -1
        try {
            ServiceCompat.stopForeground(
                this,
                if (removeNotification) {
                    ServiceCompat.STOP_FOREGROUND_REMOVE
                } else {
                    ServiceCompat.STOP_FOREGROUND_DETACH
                }
            )
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping foreground state: ${e.message}")
        }
        if (removeNotification) {
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIFICATION_ID_ADHAN)
            } catch (e: Exception) {
                Log.w(TAG, "Error canceling notification: ${e.message}")
            }
        }
        stopSelf()
    }

    private fun detachForegroundAndStop() {
        stopAndCleanup(removeNotification = false)
    }

    private fun buildNotification(prayerName: String): Notification {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                notificationManager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
            } catch (e: Exception) {
                Log.w(TAG, "Could not delete legacy notification channel: ${e.message}")
            }

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Prayer Times & Adhan",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for Islamic daily prayer times"
                enableVibration(true)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val savedLocale = prefs.getString("flutter.app_locale", "ar") ?: "ar"
        val isArabic = savedLocale.startsWith("ar", ignoreCase = true)

        val prayerNameAr = when (prayerName.lowercase()) {
            "fajr" -> "الفجر"
            "sunrise" -> "الشروق"
            "dhuhr" -> "الظهر"
            "asr" -> "العصر"
            "maghrib" -> "المغرب"
            "isha" -> "العشاء"
            else -> prayerName
        }

        val title = if (isArabic) "الأذان ومواقيت الصلاة" else "Adhan & Prayer Times"
        val content = if (isArabic) "حان الآن موعد صلاة $prayerNameAr" else "It is now time for $prayerName prayer"
        val stopActionTitle = if (isArabic) "إيقاف الأذان" else "Stop Adhan"

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Stop Adhan action routes directly to AdhanPlaybackService
        val stopIntent = Intent(this, AdhanPlaybackService::class.java).apply {
            action = ACTION_STOP_ADHAN
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            2001,
            stopIntent,
            pendingFlags
        )

        // Notification body tap opens/restores MainActivity and displays the Adhan dialog
        val bodyIntent = Intent(this, MainActivity::class.java).apply {
            action = "com.example.adhan_and_prayer.OPEN_ADHAN_DIALOG"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("extra_open_adhan_dialog", true)
            putExtra("extra_prayer_name", prayerName)
        }
        val bodyPendingIntent = PendingIntent.getActivity(
            this,
            2002,
            bodyIntent,
            pendingFlags
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setSilent(true)
            .setAutoCancel(true)
            .setContentIntent(bodyPendingIntent)
            .addAction(0, stopActionTitle, stopPendingIntent)
            .build()
    }

    override fun onDestroy() {
        Log.i(TAG, "AdhanPlaybackService destroyed")
        releaseMediaPlayer()
        releaseWakeLock()
        isRunning = false
        super.onDestroy()
    }
}
