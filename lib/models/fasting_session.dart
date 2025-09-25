import 'fasting_schedule.dart';

class FastingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final FastingSchedule schedule;

  FastingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.schedule,
  });

  bool get isActive => endTime == null;

  Duration get elapsedTime {
    final now = DateTime.now();
    return now.difference(startTime);
  }

  Duration get remainingTime {
    if (isActive) {
      final targetEndTime = startTime.add(Duration(hours: schedule.fastingHours));
      final now = DateTime.now();
      if (now.isBefore(targetEndTime)) {
        return targetEndTime.difference(now);
      }
    }
    return Duration.zero;
  }

  bool get isCompleted => endTime != null;

  Duration get totalFastingTime {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return elapsedTime;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'scheduleType': schedule.type.toString(),
      'fastingHours': schedule.fastingHours,
      'eatingHours': schedule.eatingHours,
    };
  }

  factory FastingSession.fromJson(Map<String, dynamic> json) {
    return FastingSession(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      schedule: FastingSchedule(
        type: FastingScheduleType.values.firstWhere(
          (e) => e.toString() == json['scheduleType'],
        ),
        fastingHours: json['fastingHours'],
        eatingHours: json['eatingHours'],
      ),
    );
  }
}