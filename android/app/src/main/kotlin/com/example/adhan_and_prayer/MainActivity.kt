package com.example.adhan_and_prayer

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider
import java.io.File
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.adhan_and_prayer/alarm"
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val KEY_ALARMS = "flutter.cached_scheduled_alarms"
    private val TAG = "MainActivity"

    private var methodChannel: MethodChannel? = null
    private var pendingLaunchDetails: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarms" -> {
                    val alarmsList = call.argument<List<Map<String, Any>>>("alarms")
                    if (alarmsList != null) {
                        scheduleNativeAlarms(alarmsList)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Alarms list cannot be null", null)
                    }
                }
                "cancelAllAlarms" -> {
                    cancelAllNativeAlarms()
                    result.success(true)
                }
                "stopAdhan" -> {
                    AdhanAlarmReceiver.stopAdhan(this)
                    result.success(true)
                }
                "getLaunchAdhanDetails" -> {
                    val details = getAndClearLaunchAdhanDetails()
                    result.success(details)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (!url.isNullOrBlank()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to open URL $url", e)
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "URL cannot be empty", null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (!filePath.isNullOrBlank()) {
                        val apkFile = File(filePath)
                        if (!apkFile.exists()) {
                            result.success(mapOf("success" to false, "error" to "File does not exist: $filePath"))
                            return@setMethodCallHandler
                        }

                        try {
                            // Check if Android 8.0+ requires unknown sources permission
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                if (!packageManager.canRequestPackageInstalls()) {
                                    val manageIntent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                        data = android.net.Uri.parse("package:$packageName")
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(manageIntent)
                                    result.success(mapOf(
                                        "success" to false,
                                        "error" to "Please allow installing unknown apps for this application, then tap update again."
                                    ))
                                    return@setMethodCallHandler
                                }
                            }

                            val authority = "${packageName}.update_file_provider"
                            val contentUri = FileProvider.getUriForFile(this, authority, apkFile)

                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(contentUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(installIntent)
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to install APK from $filePath", e)
                            result.success(mapOf("success" to false, "error" to (e.message ?: "Unknown error")))
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath cannot be empty", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleNativeAlarms(alarmsList: List<Map<String, Any>>) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val jsonArray = JSONArray()

        for (alarmData in alarmsList) {
            val id = (alarmData["id"] as? Number)?.toInt() ?: continue
            val prayerName = alarmData["prayerName"] as? String ?: "Prayer"
            val timestampMillis = (alarmData["timestampMillis"] as? Number)?.toLong() ?: continue
            val reciterAssetPath = alarmData["reciterAssetPath"] as? String ?: "assets/audio/adhan_abdulbasit.mp3"
            val isAdhanEnabled = alarmData["isAdhanEnabled"] as? Boolean ?: true

            val obj = JSONObject().apply {
                put("id", id)
                put("prayerName", prayerName)
                put("timestampMillis", timestampMillis)
                put("reciterAssetPath", reciterAssetPath)
                put("isAdhanEnabled", isAdhanEnabled)
            }
            jsonArray.put(obj)

            val intent = Intent(this, AdhanAlarmReceiver::class.java).apply {
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

            val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)

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
                // Fallback to inexact wakeup if user revoked exact alarm permission
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timestampMillis,
                    pendingIntent
                )
            }

            Log.i(TAG, "Scheduled exact alarm for $prayerName at $timestampMillis (id: $id, canExact: $canExact)")
        }

        // Persist to SharedPrefs for BootReceiver recovery
        val prefs: SharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_ALARMS, jsonArray.toString()).apply()
    }

    private fun cancelAllNativeAlarms() {
        val prefs: SharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alarmsJsonStr = prefs.getString(KEY_ALARMS, null) ?: return

        try {
            val jsonArray = JSONArray(alarmsJsonStr)
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val id = obj.getInt("id")

                val intent = Intent(this, AdhanAlarmReceiver::class.java).apply {
                    action = "com.example.adhan_and_prayer.ALARM_TRIGGER"
                }
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getBroadcast(this, id, intent, flags)
                alarmManager.cancel(pendingIntent)
            }

            prefs.edit().remove(KEY_ALARMS).apply()
            Log.i(TAG, "All native alarms canceled")
        } catch (e: Exception) {
            Log.e(TAG, "Error canceling alarms", e)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAdhanIntent(intent)
    }

    private fun handleAdhanIntent(intent: Intent) {
        val isOpenAdhan = intent.getBooleanExtra("extra_open_adhan_dialog", false)
        if (isOpenAdhan) {
            val prayerName = intent.getStringExtra("extra_prayer_name") ?: "Prayer"
            Log.i(TAG, "handleAdhanIntent: extra_open_adhan_dialog=true for prayer $prayerName")
            val details = mapOf(
                "openAdhanDialog" to true,
                "prayerName" to prayerName
            )
            // If method channel is already available, emit immediately
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onAdhanNotificationTapped", details)
            } else {
                pendingLaunchDetails = details
            }
        }
    }

    private fun getAndClearLaunchAdhanDetails(): Map<String, Any?>? {
        val currentIntent = intent
        if (currentIntent != null && currentIntent.getBooleanExtra("extra_open_adhan_dialog", false)) {
            val prayerName = currentIntent.getStringExtra("extra_prayer_name") ?: "Prayer"
            currentIntent.removeExtra("extra_open_adhan_dialog")
            return mapOf(
                "openAdhanDialog" to true,
                "prayerName" to prayerName
            )
        }
        val saved = pendingLaunchDetails
        pendingLaunchDetails = null
        return saved
    }
}
