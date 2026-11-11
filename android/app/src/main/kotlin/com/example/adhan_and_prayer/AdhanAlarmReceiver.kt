package com.example.adhan_and_prayer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector

class AdhanAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanAlarmReceiver"
        private const val CHANNEL_ID = "adhan_prayer_channel_v2"
        private const val LEGACY_CHANNEL_ID = "adhan_prayer_channel"
        const val ACTION_STOP_ADHAN = "com.example.adhan_and_prayer.ACTION_STOP_ADHAN"
        const val NOTIFICATION_ID_ADHAN = 1001

        private var mediaPlayer: MediaPlayer? = null
        private var activeWakeLock: PowerManager.WakeLock? = null

        /**
         * Authoritative static stop method accessible by both BroadcastReceiver
         * and MainActivity (Flutter MethodChannel).
         * Idempotent and thread-safe.
         */
        @Synchronized
        fun stopAdhan(context: Context) {
            Log.i(TAG, "AdhanAlarmReceiver.stopAdhan() called")
            try {
                mediaPlayer?.let { mp ->
                    if (mp.isPlaying) {
                        mp.stop()
                    }
                    mp.release()
                    Log.i(TAG, "Native MediaPlayer stopped and released successfully")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error while stopping/releasing MediaPlayer: ${e.message}")
            } finally {
                mediaPlayer = null
            }

            try {
                activeWakeLock?.let { wl ->
                    if (wl.isHeld) {
                        wl.release()
                        Log.i(TAG, "Active wakeLock released during stopAdhan")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing wakeLock: ${e.message}")
            } finally {
                activeWakeLock = null
            }

            // Cancel active notification on stop
            try {
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(NOTIFICATION_ID_ADHAN)
                Log.i(TAG, "Adhan notification canceled")
            } catch (e: Exception) {
                Log.w(TAG, "Error canceling notification: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "onReceive triggered with action: $action")

        if (action == ACTION_STOP_ADHAN) {
            Log.i(TAG, "Received ACTION_STOP_ADHAN from notification action")
            stopAdhan(context)
            return
        }

        val prayerName = intent.getStringExtra("prayerName") ?: "Prayer"
        val reciterAsset = intent.getStringExtra("reciterAssetPath") ?: "assets/audio/adhan_abdulbasit.mp3"
        val isAdhanEnabled = intent.getBooleanExtra("isAdhanEnabled", true)

        Log.i(TAG, "Exact Alarm triggered for prayer: $prayerName, enabled: $isAdhanEnabled")

        // Acquire a partial wake lock to guarantee CPU runs while screen is off
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AdhanAndPrayer:AlarmWakeLock"
        )
        wakeLock.acquire(180 * 1000L) // 3 minutes max safety timeout
        activeWakeLock = wakeLock

        try {
            showNotification(context, prayerName)

            if (isAdhanEnabled) {
                playAdhanAudio(context, reciterAsset, wakeLock)
            } else {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
                activeWakeLock = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling alarm trigger", e)
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
            activeWakeLock = null
        }
    }

    private fun showNotification(context: Context, prayerName: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Delete legacy channel that had default notification ringtone enabled
            try {
                notificationManager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
            } catch (e: Exception) {
                Log.w(TAG, "Could not delete legacy notification channel: ${e.message}")
            }

            // Create dedicated silent notification channel so default system chime does NOT mask the Adhan
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

        // Determine user's selected language from Flutter preferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
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

        // PendingIntent for Stop Adhan notification action
        val stopIntent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            action = ACTION_STOP_ADHAN
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            2001,
            stopIntent,
            flags
        )

        // PendingIntent for Notification Body Tap: opens MainActivity and passes flag to open Adhan Dialog
        val bodyIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.adhan_and_prayer.OPEN_ADHAN_DIALOG"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("extra_open_adhan_dialog", true)
            putExtra("extra_prayer_name", prayerName)
        }
        val bodyPendingIntent = PendingIntent.getActivity(
            context,
            2002,
            bodyIntent,
            flags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setSilent(true)
            .setAutoCancel(true)
            .setContentIntent(bodyPendingIntent)
            .addAction(0, stopActionTitle, stopPendingIntent)
            .build()

        notificationManager.notify(NOTIFICATION_ID_ADHAN, notification)
    }

    private fun playAdhanAudio(context: Context, assetPath: String, wakeLock: PowerManager.WakeLock) {
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )

                val loader = FlutterInjector.instance().flutterLoader()
                val assetKey = loader.getLookupKeyForAsset(assetPath)
                val afd: AssetFileDescriptor = context.assets.openFd(assetKey)

                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()

                // Read persisted Adhan volume from Flutter SharedPreferences
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val volume = try {
                    if (prefs.contains("flutter.adhan_volume")) {
                        val rawFloat = try {
                            prefs.getFloat("flutter.adhan_volume", 1.0f)
                        } catch (_: ClassCastException) {
                            try {
                                val bits = prefs.getLong("flutter.adhan_volume", java.lang.Double.doubleToRawLongBits(1.0))
                                java.lang.Double.longBitsToDouble(bits).toFloat()
                            } catch (_: ClassCastException) {
                                try {
                                    val strVal = prefs.getString("flutter.adhan_volume", "1.0") ?: "1.0"
                                    strVal.toFloatOrNull() ?: 1.0f
                                } catch (_: Exception) {
                                    1.0f
                                }
                            }
                        }
                        rawFloat.coerceIn(0.0f, 1.0f)
                    } else {
                        1.0f
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error reading flutter.adhan_volume, falling back to 1.0", e)
                    1.0f
                }

                setVolume(volume, volume)
                Log.i(TAG, "Configured native MediaPlayer Adhan volume: $volume (persisted setting respected)")

                prepare()
                start()
                setOnCompletionListener { mp ->
                    mp.release()
                    mediaPlayer = null
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                    activeWakeLock = null
                    Log.i(TAG, "Adhan audio playback finished successfully, wakeLock released")
                }
                setOnErrorListener { mp, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    mp.release()
                    mediaPlayer = null
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                    activeWakeLock = null
                    true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play Adhan audio: $assetPath", e)
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
            activeWakeLock = null
        }
    }
}
