/// Response shape of `/tasks/manager-dashboard/`, `/tasks/dashboard/` and
/// `/tasks/team-lead-dashboard/`.
class TaskStatsModel {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int overdue;

  const TaskStatsModel({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.overdue,
  });

  factory TaskStatsModel.fromJson(Map<String, dynamic> json) {
    return TaskStatsModel(
      total: json['total'] ?? 0,
      pending: json['pending'] ?? 0,
      inProgress: json['in_progress'] ?? 0,
      completed: json['completed'] ?? 0,
      overdue: json['overdue'] ?? 0,
    );
  }

  static const TaskStatsModel empty = TaskStatsModel(
    total: 0,
    pending: 0,
    inProgress: 0,
    completed: 0,
    overdue: 0,
  );

  /// Completed share of all tasks, 0-100.
  int get completionRate {
    if (total == 0) {
      return 0;
    }

    return ((completed / total) * 100).round();
  }
}
