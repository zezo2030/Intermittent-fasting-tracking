package com.example.myapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Start the background timer service after boot
            val backgroundIntent = Intent(context, BackgroundTimerService::class.java)
            backgroundIntent.action = BackgroundTimerService.ACTION_RESTART_TIMER
            context.startForegroundService(backgroundIntent)
        }
    }
}