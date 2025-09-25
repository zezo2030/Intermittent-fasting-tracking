import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/fasting_session.dart';
import '../models/fasting_schedule.dart';

class BackgroundTimerService {
  static const String _currentSessionKey = 'currentSession';
  static const String _notificationChannelId = 'fasting_timer';
  static const String _notificationChannelName = 'Fasting Timer';
  static const String _notificationChannelDescription = 'Ongoing fasting session notifications';

  static BackgroundTimerService? _instance;
  Timer? _backgroundTimer;
  FastingSession? _currentSession;
  bool _isInitialized = false;

  // Notification plugin
  late FlutterLocalNotificationsPlugin _notifications;

  // Callbacks
  VoidCallback? _onSessionUpdate;
  VoidCallback? _onSessionComplete;

  static BackgroundTimerService get instance {
    _instance ??= BackgroundTimerService._();
    return _instance!;
  }

  BackgroundTimerService._();

  Future<void> initialize({
    VoidCallback? onSessionUpdate,
    VoidCallback? onSessionComplete,
  }) async {
    if (_isInitialized) return;

    _onSessionUpdate = onSessionUpdate;
    _onSessionComplete = onSessionComplete;

    // Initialize notifications
    _notifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description: _notificationChannelDescription,
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    // Initialize timezone for scheduling
    tz.initializeTimeZones();

    // Load current session from storage
    await _loadCurrentSession();

    _isInitialized = true;
  }

  Future<void> _loadCurrentSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_currentSessionKey);

      if (sessionJson != null) {
        _currentSession = FastingSession.fromJson(jsonDecode(sessionJson));

        // Check if session is still active and not completed
        if (_currentSession!.isActive) {
          final now = DateTime.now();
          final targetEndTime = _currentSession!.startTime.add(
            Duration(hours: _currentSession!.schedule.fastingHours),
          );

          // If fasting period has passed, complete the session
          if (now.isAfter(targetEndTime)) {
            await completeSession();
          } else {
            // Start background timer
            _startBackgroundTimer();
            // Show notification
            await _showOngoingNotification();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading current session: $e');
    }
  }

  Future<void> startSession(FastingSession session) async {
    _currentSession = session;
    await _saveCurrentSession();
    _startBackgroundTimer();
    await _showOngoingNotification();
    _onSessionUpdate?.call();
  }

  Future<void> completeSession() async {
    if (_currentSession == null || !_currentSession!.isActive) return;

    final completedSession = FastingSession(
      id: _currentSession!.id,
      startTime: _currentSession!.startTime,
      endTime: DateTime.now(),
      schedule: _currentSession!.schedule,
    );

    _currentSession = null;
    _stopBackgroundTimer();
    await _cancelNotification();
    await _saveCompletedSession(completedSession);
    _onSessionComplete?.call();
  }

  void _startBackgroundTimer() {
    _stopBackgroundTimer(); // Stop any existing timer

    _backgroundTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _checkSessionStatus();
    });
  }

  void _stopBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  Future<void> _checkSessionStatus() async {
    if (_currentSession == null || !_currentSession!.isActive) return;

    final now = DateTime.now();
    final targetEndTime = _currentSession!.startTime.add(
      Duration(hours: _currentSession!.schedule.fastingHours),
    );

    if (now.isAfter(targetEndTime)) {
      await completeSession();
    } else {
      // Update notification with current progress
      await _showOngoingNotification();
      _onSessionUpdate?.call();
    }
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSession == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentSessionKey, jsonEncode(_currentSession!.toJson()));
    } catch (e) {
      debugPrint('Error saving current session: $e');
    }
  }

  Future<void> _saveCompletedSession(FastingSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load existing history
      final historyJson = prefs.getStringList('history') ?? [];
      historyJson.add(jsonEncode(session.toJson()));

      // Save updated history
      await prefs.setStringList('history', historyJson);

      // Remove current session
      await prefs.remove(_currentSessionKey);
    } catch (e) {
      debugPrint('Error saving completed session: $e');
    }
  }

  Future<void> _showOngoingNotification() async {
    if (_currentSession == null || !_currentSession!.isActive) return;

    final elapsed = _currentSession!.elapsedTime;
    final remaining = _currentSession!.remainingTime;
    final progress = elapsed.inSeconds / Duration(hours: _currentSession!.schedule.fastingHours).inSeconds;

    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      enableVibration: true,
      playSound: false,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).toInt(),
      styleInformation: BigTextStyleInformation(
        '${_formatDuration(elapsed)} elapsed\n${_formatDuration(remaining)} remaining',
        htmlFormatBigText: true,
        contentTitle: 'Fasting in Progress',
        htmlFormatContentTitle: true,
        summaryText: _currentSession!.schedule.displayName,
        htmlFormatSummaryText: true,
      ),
      actions: [
        const AndroidNotificationAction(
          'stop_action',
          'Stop Fast',
          titleColor: Colors.red,
          cancelNotification: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Fasting in Progress',
      '${_currentSession!.schedule.displayName} - ${_formatDuration(elapsed)}',
      details,
    );
  }

  Future<void> _cancelNotification() async {
    await _notifications.cancel(0);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'stop_action') {
      completeSession();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  FastingSession? get currentSession => _currentSession;
  bool get isRunning => _currentSession?.isActive ?? false;

  void dispose() {
    _stopBackgroundTimer();
    _cancelNotification();
  }
}