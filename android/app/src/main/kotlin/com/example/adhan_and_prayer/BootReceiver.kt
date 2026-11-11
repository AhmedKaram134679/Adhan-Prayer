package com.example.adhan_and_prayer

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_ALARMS = "flutter.cached_scheduled_alarms"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.i(TAG, "Device reboot completed. Rebuilding prayer alarm schedules...")
            rescheduleAlarms(context)
        }
    }

    private fun rescheduleAlarms(context: Context) {
        val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alarmsJsonStr = prefs.getString(KEY_ALARMS, null) ?: return

        try {
            val jsonArray = JSONArray(alarmsJsonStr)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()

            for (i in 0 until jsonArray.length()) {
                val obj: JSONObject = jsonArray.getJSONObject(i)
                val id = obj.getInt("id")
                val prayerName = obj.getString("prayerName")
                val timestampMillis = obj.getLong("timestampMillis")
                val reciterAssetPath = obj.getString("reciterAssetPath")
                val isAdhanEnabled = obj.getBoolean("isAdhanEnabled")

                // Only schedule upcoming alarms
                if (timestampMillis > now) {
                    val alarmIntent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                        action = "com.example.adhan_and_prayer.ALARM_TRIGGER"
                        putExtra("id", id)
                        putExtra("prayerName", prayerName)
                        putExtra("reciterAssetPath", reciterAssetPath)
                        putExtra("isAdhanEnabled", isAdhanEnabled)
                    }

                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }

                    val pendingIntent = PendingIntent.getBroadcast(context, id, alarmIntent, flags)

                    val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        alarmManager.canScheduleExactAlarms()
                    } else {
                        true
                    }

                    if (canExact) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                timestampMillis,
                                pendingIntent
                            )
                        } else {
                            alarmManager.setExact(
                                AlarmManager.RTC_WAKEUP,
                                timestampMillis,
                                pendingIntent
                            )
                        }
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            timestampMillis,
                            pendingIntent
                        )
                    }
                    Log.i(TAG, "Rescheduled reboot alarm for $prayerName at $timestampMillis (canExact: $canExact)")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring alarms on boot", e)
        }
    }
}
