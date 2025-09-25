enum FastingScheduleType {
  sixteenEight,
  eighteenSix,
  twentyFour,
  custom,
}

class FastingSchedule {
  final FastingScheduleType type;
  final int fastingHours;
  final int eatingHours;

  const FastingSchedule({
    required this.type,
    required this.fastingHours,
    required this.eatingHours,
  });

  static const FastingSchedule sixteenEight = FastingSchedule(
    type: FastingScheduleType.sixteenEight,
    fastingHours: 16,
    eatingHours: 8,
  );

  static const FastingSchedule eighteenSix = FastingSchedule(
    type: FastingScheduleType.eighteenSix,
    fastingHours: 18,
    eatingHours: 6,
  );

  static const FastingSchedule twentyFour = FastingSchedule(
    type: FastingScheduleType.twentyFour,
    fastingHours: 24,
    eatingHours: 0,
  );

  factory FastingSchedule.custom(int fastingHours, int eatingHours) {
    return FastingSchedule(
      type: FastingScheduleType.custom,
      fastingHours: fastingHours,
      eatingHours: eatingHours,
    );
  }

  String get displayName {
    switch (type) {
      case FastingScheduleType.sixteenEight:
        return '16:8';
      case FastingScheduleType.eighteenSix:
        return '18:6';
      case FastingScheduleType.twentyFour:
        return '24:0 (OMAD)';
      case FastingScheduleType.custom:
        return '$fastingHours:$eatingHours';
    }
  }
}