import '../core/constants/task_constants.dart';

class TaskModel {
  final int id;
  final int project;
  final String title;
  final String description;
  final int? assignee;
  final int? creator;
  final String priority;
  final String status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final int progress;
  final List<int> labels;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.project,
    required this.title,
    required this.description,
    this.assignee,
    this.creator,
    required this.priority,
    required this.status,
    this.startDate,
    this.dueDate,
    required this.progress,
    required this.labels,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? 0,
      project: json['project'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      assignee: json['assignee'],
      creator: json['creator'],
      priority: json['priority'] ?? TaskPriority.medium,
      status: json['status'] ?? TaskStatus.todo,
      startDate: _parseDate(json['start_date']),
      dueDate: _parseDate(json['due_date']),
      progress: json['progress'] ?? 0,
      labels: List<int>.from(json['labels'] ?? <int>[]),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  bool get isCompleted => TaskStatus.closed.contains(status);

  bool get isUnassigned => assignee == null;

  /// Past the due date and still open.
  bool get isOverdue {
    if (dueDate == null || isCompleted) {
      return false;
    }

    final DateTime due = dueDate!.toLocal();
    final DateTime endOfDay =
        DateTime(due.year, due.month, due.day, 23, 59, 59);

    return DateTime.now().isAfter(endOfDay);
  }

  /// True when [day] is the task's due date (date part only).
  bool isDueOn(DateTime day) {
    if (dueDate == null) {
      return false;
    }

    final DateTime due = dueDate!.toLocal();

    return due.year == day.year && due.month == day.month && due.day == day.day;
  }

  TaskModel copyWith({
    String? title,
    String? description,
    int? assignee,
    bool clearAssignee = false,
    String? priority,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
    int? progress,
  }) {
    return TaskModel(
      id: id,
      project: project,
      title: title ?? this.title,
      description: description ?? this.description,
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      creator: creator,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      progress: progress ?? this.progress,
      labels: labels,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
