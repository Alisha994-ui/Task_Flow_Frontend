class TimeLogModel {
  final int id;
  final int task;
  final int? user;
  final String userName;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final String note;

  TimeLogModel({
    required this.id,
    required this.task,
    this.user,
    required this.userName,
    this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.note,
  });

  factory TimeLogModel.fromJson(Map<String, dynamic> json) {
    return TimeLogModel(
      id: json['id'] ?? 0,
      task: json['task'] ?? 0,
      user: json['user'],
      userName: json['user_name'] ?? '',
      startTime: json['start_time'] == null
          ? null
          : DateTime.tryParse(json['start_time'].toString()),
      endTime: json['end_time'] == null
          ? null
          : DateTime.tryParse(json['end_time'].toString()),
      durationMinutes: json['duration_minutes'] ?? 0,
      note: json['note'] ?? '',
    );
  }

  /// A log with no end time is the timer that is still running.
  bool get isRunning => endTime == null;

  /// Minutes elapsed so far for a running timer.
  int get elapsedMinutes {
    if (!isRunning || startTime == null) {
      return durationMinutes;
    }

    return DateTime.now().difference(startTime!.toLocal()).inMinutes;
  }

  bool startedOn(DateTime day) {
    if (startTime == null) {
      return false;
    }

    final DateTime local = startTime!.toLocal();

    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }
}

/// `95` -> `1h 35m`
String formatMinutes(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }

  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;

  if (rest == 0) {
    return '${hours}h';
  }

  return '${hours}h ${rest}m';
}
