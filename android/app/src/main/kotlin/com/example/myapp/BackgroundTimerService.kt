package com.example.myapp

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class BackgroundTimerService : Service() {
    companion object {
        const val ACTION_RESTART_TIMER = "com.example.myapp.RESTART_TIMER"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "FASTING_TIMER_CHANNEL"
    }

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private var timer: java.util.Timer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification("Initializing..."))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_RESTART_TIMER -> {
                restartBackgroundTimer()
            }
            else -> {
                startBackgroundTimer()
            }
        }
        return START_STICKY
    }

    private fun startBackgroundTimer() {
        // Initialize Flutter engine for background execution
        initializeFlutterEngine()

        // Start periodic timer check
        timer = java.util.Timer()
        timer?.scheduleAtFixedRate(object : java.util.TimerTask() {
            override fun run() {
                checkFastingStatus()
            }
        }, 0, 60000) // Check every minute
    }

    private fun restartBackgroundTimer() {
        // Restart the timer after device reboot
        startBackgroundTimer()
    }

    private fun checkFastingStatus() {
        // Use method channel to communicate with Flutter
        methodChannel?.invokeMethod("checkFastingStatus", null)
    }

    private fun initializeFlutterEngine() {
        flutterEngine = FlutterEngineCache.getInstance().get("my_engine_id")

        if (flutterEngine == null) {
            flutterEngine = FlutterEngine(this)
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
        }

        methodChannel = MethodChannel(
            flutterEngine?.dartExecutor?.binaryMessenger!!,
            "com.example.myapp/background_timer"
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "Fasting in Progress"
                    val content = call.argument<String>("content") ?: ""
                    updateNotification(title, content)
                    result.success(null)
                }
                "stopService" -> {
                    stopForeground(true)
                    stopSelf()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Fasting Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background fasting timer notifications"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(content: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Fasting Timer")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(title: String, content: String) {
        val notification = createNotification(content)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        timer?.cancel()
        timer = null
        methodChannel?.setMethodCallHandler(null)
    }
}