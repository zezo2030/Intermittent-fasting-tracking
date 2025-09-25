import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fasting_session.dart';
import '../models/fasting_schedule.dart';
import '../services/background_timer_service.dart';

class FastingProvider with ChangeNotifier {
  FastingSession? _currentSession;
  FastingSchedule _selectedSchedule = FastingSchedule.sixteenEight;
  List<FastingSession> _history = [];
  Timer? _uiTimer;
  bool _isInitialized = false;

  FastingSession? get currentSession => _currentSession;
  FastingSchedule get selectedSchedule => _selectedSchedule;
  List<FastingSession> get history => _history;
  bool get isInitialized => _isInitialized;

  FastingProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    // Initialize background timer service
    await BackgroundTimerService.instance.initialize(
      onSessionUpdate: _onBackgroundSessionUpdate,
      onSessionComplete: _onBackgroundSessionComplete,
    );

    // Load data
    await _loadData();

    // Start UI timer for real-time updates
    _startUITimer();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _onBackgroundSessionUpdate() async {
    await _loadCurrentSessionFromBackground();
    notifyListeners();
  }

  Future<void> _onBackgroundSessionComplete() async {
    await _loadData(); // Reload all data when session completes
    notifyListeners();
  }

  void _startUITimer() {
    _stopUITimer(); // Stop any existing timer

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopUITimer() {
    _uiTimer?.cancel();
    _uiTimer = null;
  }


  Future<void> _loadCurrentSessionFromBackground() async {
    final backgroundSession = BackgroundTimerService.instance.currentSession;
    if (backgroundSession != _currentSession) {
      _currentSession = backgroundSession;
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load current session from background service
    await _loadCurrentSessionFromBackground();

    // Load selected schedule
    final selectedScheduleIndex = prefs.getInt('selectedSchedule') ?? 0;
    _selectedSchedule = _getScheduleFromIndex(selectedScheduleIndex);

    // Load history
    final historyJson = prefs.getStringList('history') ?? [];
    _history = historyJson.map((e) => FastingSession.fromJson(jsonDecode(e))).toList();

    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedSchedule', _selectedSchedule.type.index);

    // History is managed by background service
    final historyJson = _history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('history', historyJson);
  }

  FastingSchedule _getScheduleFromIndex(int index) {
    switch (index) {
      case 0:
        return FastingSchedule.sixteenEight;
      case 1:
        return FastingSchedule.eighteenSix;
      case 2:
        return FastingSchedule.twentyFour;
      default:
        return FastingSchedule.sixteenEight;
    }
  }

  Future<void> startFasting() async {
    if (_currentSession == null) {
      final session = FastingSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        schedule: _selectedSchedule,
      );

      _currentSession = session;
      await BackgroundTimerService.instance.startSession(session);
      notifyListeners();
    }
  }

  Future<void> stopFasting() async {
    if (_currentSession != null && _currentSession!.isActive) {
      await BackgroundTimerService.instance.completeSession();
      // Data will be updated via callback
    }
  }

  void setSelectedSchedule(FastingSchedule schedule) {
    _selectedSchedule = schedule;
    _saveData();
    notifyListeners();
  }

  void updateTimer() {
    notifyListeners();
  }

  @override
  void dispose() {
    _stopUITimer();
    BackgroundTimerService.instance.dispose();
    super.dispose();
  }
}