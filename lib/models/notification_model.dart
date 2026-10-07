import 'package:flutter/material.dart';

/// Mirrors `Notification.Type` in the Django model.
class NotificationType {
  const NotificationType._();

  static const String taskAssigned = 'TASK_ASSIGNED';
  static const String taskReassigned = 'TASK_REASSIGNED';
  static const String deadline = 'DEADLINE';
  static const String overdue = 'OVERDUE';
  static const String comment = 'COMMENT';
  static const String mention = 'MENTION';
  static const String taskUrgent = 'TASK_URGENT';

  static const List<String> all = <String>[
    taskAssigned,
    taskReassigned,
    deadline,
    overdue,
    comment,
    mention,
    taskUrgent,
  ];

  static String label(String value) {
    switch (value) {
      case taskAssigned:
        return 'Task assigned';
      case taskReassigned:
        return 'Task reassigned';
      case deadline:
        return 'Deadline reminder';
      case overdue:
        return 'Overdue';
      case comment:
        return 'Comment';
      case mention:
        return 'Mention';
      case taskUrgent:
        return 'Marked urgent';
      default:
        return value;
    }
  }

  static IconData icon(String value) {
    switch (value) {
      case taskAssigned:
        return Icons.assignment_ind_outlined;
      case taskReassigned:
        return Icons.swap_horiz;
      case deadline:
        return Icons.schedule;
      case overdue:
        return Icons.warning_amber_rounded;
      case comment:
        return Icons.chat_bubble_outline;
      case mention:
        return Icons.alternate_email;
      case taskUrgent:
        return Icons.priority_high_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  static Color color(String value) {
    switch (value) {
      case taskAssigned:
        return const Color(0xFF2563EB);
      case taskReassigned:
        return const Color(0xFF0D9488);
      case deadline:
        return const Color(0xFFD97706);
      case overdue:
        return const Color(0xFFDC2626);
      case comment:
        return const Color(0xFF7C3AED);
      case mention:
        return const Color(0xFF059669);
      case taskUrgent:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class NotificationModel {
  final int id;
  final int? user;
  final int? task;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    this.user,
    this.task,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      user: json['user'],
      task: json['task'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  NotificationModel asRead() {
    return NotificationModel(
      id: id,
      user: user,
      task: task,
      type: type,
      title: title,
      message: message,
      isRead: true,
      createdAt: createdAt,
    );
  }
}

/// `3m ago`, `2h ago`, `5d ago`.
String timeAgo(DateTime? moment) {
  if (moment == null) {
    return '';
  }

  final Duration diff = DateTime.now().difference(moment.toLocal());

  if (diff.inMinutes < 1) {
    return 'just now';
  }

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }

  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }

  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }

  final int weeks = diff.inDays ~/ 7;

  if (weeks < 5) {
    return '${weeks}w ago';
  }

  return '${diff.inDays ~/ 30}mo ago';
}
