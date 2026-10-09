package com.example.jan_sarthi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.example.jan_sarthi/notifications"
    private val EMERGENCY_CHANNEL_ID = "vita_resq_emergency_alerts"

    private var pendingEmergencyId: String? = null
    private var notificationChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createEmergencyNotificationChannel()
        handleLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleLaunchIntent(intent)
    }

    private fun handleLaunchIntent(intent: Intent?) {
        val emergencyId = intent?.getStringExtra("emergencyId")
        if (!emergencyId.isNullOrEmpty()) {
            pendingEmergencyId = emergencyId
            notificationChannel?.invokeMethod("onNotificationTapped", emergencyId)
        }
    }

    private fun createEmergencyNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Vita ResQ Emergency Alerts"
            val descriptionText = "High-importance civilian emergency and responder alerts"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(EMERGENCY_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Dedicated Emergency Notification Channel
        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialEmergencyId" -> {
                        val id = pendingEmergencyId
                        pendingEmergencyId = null
                        result.success(id)
                    }
                    "showEmergencyNotification" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        val title = call.argument<String>("title") ?: "Vita ResQ — Emergency Nearby"
                        val body = call.argument<String>("body") ?: "A nearby user needs assistance."
                        val emergencyId = call.argument<String>("emergencyId")

                        showNativeEmergencyNotification(id, title, body, emergencyId)
                        result.success(true)
                    }
                    "cancelEmergencyNotification" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        val notificationManager = NotificationManagerCompat.from(this@MainActivity)
                        notificationManager.cancel(id)
                        result.success(true)
                    }
                    "startResponderForegroundService" -> {
                        val serviceIntent = Intent(this@MainActivity, ResponderForegroundService::class.java).apply {
                            action = ResponderForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                    "stopResponderForegroundService" -> {
                        val serviceIntent = Intent(this@MainActivity, ResponderForegroundService::class.java).apply {
                            action = ResponderForegroundService.ACTION_STOP
                        }
                        stopService(serviceIntent)
                        result.success(true)
                    }
                    "isResponderForegroundServiceRunning" -> {
                        result.success(ResponderForegroundService.isServiceRunning)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // If an emergency was tapped prior to engine configuration, deliver it now
        pendingEmergencyId?.let { id ->
            notificationChannel?.invokeMethod("onNotificationTapped", id)
        }

        // Forward Android 15 FGS timeout events to Flutter
        ResponderForegroundService.onTimeoutListener = {
            runOnUiThread {
                notificationChannel?.invokeMethod("onResponderModeTimedOut", null)
            }
        }
    }

    override fun onDestroy() {
        ResponderForegroundService.onTimeoutListener = null
        super.onDestroy()
    }

    private fun showNativeEmergencyNotification(
        notificationId: Int,
        title: String,
        body: String,
        emergencyId: String?
    ) {
        val clickIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (!emergencyId.isNullOrEmpty()) {
                putExtra("emergencyId", emergencyId)
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            clickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, EMERGENCY_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .setDefaults(NotificationCompat.DEFAULT_SOUND or NotificationCompat.DEFAULT_VIBRATE)

        val notificationManager = NotificationManagerCompat.from(this)
        try {
            notificationManager.notify(notificationId, builder.build())
        } catch (_: SecurityException) {
            // Handled safely if user has not yet granted notification permission
        }
    }
}
