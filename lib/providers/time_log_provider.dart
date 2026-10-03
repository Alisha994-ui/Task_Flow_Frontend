import 'package:flutter/foundation.dart';

import '../models/time_log_model.dart';
import '../services/time_log_service.dart';

class TimeLogProvider extends ChangeNotifier {
  List<TimeLogModel> _logs = <TimeLogModel>[];
  bool _isLoading = false;
  bool _isBusy = false;
  String? _error;

  /// Who is signed in. An employee only ever sees their own logs, but a
  /// team lead or manager sees the whole team's, so "my timer" and "my
  /// hours" need to know which rows are theirs.
  int? _currentUserId;

  List<TimeLogModel> get logs => List<TimeLogModel>.unmodifiable(_logs);

  int? get currentUserId => _currentUserId;

  /// Call this once when a panel opens.
  void setCurrentUser(int userId) {
    if (_currentUserId == userId) {
      return;
    }

    _currentUserId = userId;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  bool get isBusy => _isBusy;

  String? get error => _error;

  /// The signed-in user's own open timer, if one is running.
  TimeLogModel? get activeLog {
    for (final TimeLogModel log in _logs) {
      if (!log.isRunning) {
        continue;
      }

      if (_currentUserId == null || log.user == _currentUserId) {
        return log;
      }
    }

    return null;
  }

  bool get hasActiveTimer => activeLog != null;

  /// Every timer running right now, whoever it belongs to. Empty for an
  /// employee, since the backend only sends them their own rows.
  List<TimeLogModel> get runningLogs =>
      _logs.where((TimeLogModel l) => l.isRunning).toList();

  /// Timers running for someone other than the signed-in user - what a
  /// team lead watches.
  List<TimeLogModel> get othersRunningLogs => _logs
      .where((TimeLogModel l) => l.isRunning && l.user != _currentUserId)
      .toList();

  List<TimeLogModel> logsForUser(int userId) =>
      _logs.where((TimeLogModel l) => l.user == userId).toList();

  /// Total minutes tracked by one person.
  int minutesForUser(int userId) => _logs
      .where((TimeLogModel l) => l.user == userId)
      .fold<int>(0, (int sum, TimeLogModel l) => sum + l.elapsedMinutes);

  /// Minutes one person tracked today.
  int minutesTodayForUser(int userId) {
    final DateTime today = DateTime.now();

    return _logs
        .where((TimeLogModel l) => l.user == userId && l.startedOn(today))
        .fold<int>(0, (int sum, TimeLogModel l) => sum + l.elapsedMinutes);
  }

  /// Minutes logged against one task by everyone.
  int minutesOnTask(int taskId) => _logs
      .where((TimeLogModel l) => l.task == taskId)
      .fold<int>(0, (int sum, TimeLogModel l) => sum + l.elapsedMinutes);

  bool _isMine(TimeLogModel log) =>
      _currentUserId == null || log.user == _currentUserId;

  int get minutesToday {
    final DateTime today = DateTime.now();

    return _logs
        .where((TimeLogModel l) => _isMine(l) && l.startedOn(today))
        .fold<int>(0, (int sum, TimeLogModel l) => sum + l.elapsedMinutes);
  }

  int get minutesThisWeek {
    final DateTime now = DateTime.now();
    final DateTime monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    return _logs.where((TimeLogModel l) {
      if (l.startTime == null || !_isMine(l)) {
        return false;
      }

      return !l.startTime!.toLocal().isBefore(monday);
    }).fold<int>(0, (int sum, TimeLogModel l) => sum + l.elapsedMinutes);
  }

  int minutesForTask(int taskId) => _logs
      .where((TimeLogModel l) => l.task == taskId && _isMine(l))
      .fold<int>(0, (int sum, TimeLogModel l) => sum + l.elapsedMinutes);

  Future<void> load({bool silent = false}) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;

    if (!silent) {
      _error = null;
      notifyListeners();
    }

    try {
      _logs = await TimeLogService.getLogs();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: _logs.isNotEmpty);

  /// Returns null on success, or a message to show the user.
  Future<String?> start(int taskId) async {
    if (hasActiveTimer) {
      return 'Stop the running timer first.';
    }

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final TimeLogModel created = await TimeLogService.start(taskId);
      _logs = <TimeLogModel>[created, ..._logs];

      return null;
    } catch (e) {
      _error = e.toString();

      return 'Could not start the timer.';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> stop() async {
    if (!hasActiveTimer) {
      return 'No timer is running.';
    }

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final TimeLogModel stopped = await TimeLogService.stop();
      _logs = _logs
          .map((TimeLogModel l) => l.id == stopped.id ? stopped : l)
          .toList();

      return null;
    } catch (e) {
      _error = e.toString();

      return 'Could not stop the timer.';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Clears everything on sign out.
  void reset() {
    _logs = <TimeLogModel>[];
    _currentUserId = null;
    _isLoading = false;
    _isBusy = false;
    _error = null;
    notifyListeners();
  }
}
